import AppKit
import Combine

/// Вью-модель для отображения состояния VPN в статус-баре.
@MainActor
final class StatusItemViewModel {
    /// Данные для иконки и тултипа статус-бара.
    struct ImageContent {
        let image: NSImage?
        let toolTip: String
        let accessibilityValue: String
        let connectionName: String?
    }

    /// Состояние статус-бара.
    enum State {
        case connecting(ImageContent)
        case connected(ImageContent)
        case disconnected(ImageContent)
    }

    /// Текущее состояние, публикуемое для обновления UI.
    @Published private(set) var state: State

    private static var cachedConnectedImage: NSImage?
    private static var cachedDisconnectedImage: NSImage?

    private let vpnManager: VPNManagerProtocol
    private let settings: SettingsManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var fallbackTimer: Timer?

    init(vpnManager: VPNManagerProtocol, settings: SettingsManagerProtocol) {
        self.vpnManager = vpnManager
        self.settings = settings

        state = StatusItemViewModel.makeState(
            connections: vpnManager.connections,
            settings: settings
        )

        let showConnectionNameChange = NotificationCenter.default
            .publisher(for: .showConnectionNameDidChange)
            .map { _ in () }
            .prepend(())

        if let observableVPNManager = vpnManager as? VPNManager {
            observableVPNManager.$connections
                .combineLatest(showConnectionNameChange)
                .map { connections, _ in
                    StatusItemViewModel.makeState(connections: connections, settings: settings)
                }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newState in
                    self?.state = newState
                }
                .store(in: &cancellables)
        } else {
            // Fallback for protocol without Combine - use timer-based polling
            setupFallbackTimer()

            // Also subscribe to showConnectionNameDidChange
            NotificationCenter.default
                .publisher(for: .showConnectionNameDidChange)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateStateFromManager()
                }
                .store(in: &cancellables)
        }
    }

    private func setupFallbackTimer() {
        // Use longer interval for fallback polling to reduce overhead
        // Matches the minimum update interval from AppConstants
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.minUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStateFromManager()
            }
        }
    }

    private func updateStateFromManager() {
        state = StatusItemViewModel.makeState(
            connections: vpnManager.connections,
            settings: settings
        )
    }

    deinit {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    /// Собирает состояние статус-бара на основе подключений и настроек.
    /// - Parameters:
    ///   - connections: Текущие VPN-подключения.
    ///   - settings: Настройки отображения.
    /// - Returns: Итоговое состояние статус-бара.
    private static func makeState(
        connections: [VPNConnection],
        settings: SettingsManagerProtocol
    ) -> State {
        let hasConnecting = connections.contains { $0.status == .connecting || $0.status == .disconnecting }

        if hasConnecting {
            let text = NSLocalizedString(
                "status.tooltip.connecting",
                comment: "Status bar tooltip while connecting"
            )
            return .connecting(ImageContent(image: nil, toolTip: text, accessibilityValue: text, connectionName: nil))
        }

        if let active = connections.first(where: { $0.status.isActive }) {
            let showName = settings.showConnectionName
            let name = showName ? active.name : nil

            let toolTip: String
            let accessibility: String

            if let name {
                toolTip = name
                accessibility = String(
                    format: NSLocalizedString(
                        "status.tooltip.connectedTo",
                        comment: "Accessibility value when connected to specific VPN"
                    ),
                    name
                )
            } else {
                toolTip = NSLocalizedString(
                    "status.tooltip.connected",
                    comment: "Status bar tooltip when connected without name"
                )
                accessibility = toolTip
            }

            let image = makeConnectedImage()
            return .connected(ImageContent(image: image, toolTip: toolTip, accessibilityValue: accessibility, connectionName: name))
        }

        let text = NSLocalizedString(
            "status.tooltip.disconnected",
            comment: "Status bar tooltip when disconnected"
        )
        let image = makeDisconnectedImage()
        return .disconnected(ImageContent(image: image, toolTip: text, accessibilityValue: text, connectionName: nil))
    }

    private static func makeConnectedImage() -> NSImage? {
        if let cached = cachedConnectedImage {
            return cached
        }
        
        guard let image = NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        cachedConnectedImage = image
        return image
    }

    private static func makeDisconnectedImage() -> NSImage? {
        if let cached = cachedDisconnectedImage {
            return cached
        }
        
        guard let base = NSImage(systemSymbolName: "network", accessibilityDescription: nil) else {
            return nil
        }
        let image = NSImage(size: base.size)
        image.lockFocus()
        base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 0.4)
        image.unlockFocus()
        image.isTemplate = true
        cachedDisconnectedImage = image
        return image
    }
}


