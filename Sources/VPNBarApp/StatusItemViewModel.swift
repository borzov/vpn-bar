import AppKit
import Combine

/// View model for displaying VPN state in the status bar.
@MainActor
final class StatusItemViewModel {
    /// Data for status bar icon and tooltip.
    struct ImageContent {
        let image: NSImage?
        let toolTip: String
        let accessibilityValue: String
        let connectionName: String?
    }

    /// Status bar state.
    enum State {
        case connecting(ImageContent)
        case connected(ImageContent)
        case disconnected(ImageContent)
    }

    /// Current state published for UI updates.
    @Published private(set) var state: State


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
            setupFallbackTimer()

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

    /// Builds status bar state based on connections and settings.
    /// - Parameters:
    ///   - connections: Current VPN connections.
    ///   - settings: Display settings.
    /// - Returns: Final status bar state.
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
        return ImageCache.shared.image(systemSymbolName: "network.badge.shield.half.filled")
    }

    private static func makeDisconnectedImage() -> NSImage? {
        let cacheKey = "network_disconnected_0.4"
        
        if let cached = ImageCache.shared.cachedImage(forKey: cacheKey) {
            return cached
        }
        
        guard let base = NSImage(systemSymbolName: "network", accessibilityDescription: nil) else {
            return nil
        }
        let image = NSImage(size: base.size, flipped: false) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.4)
            return true
        }
        image.isTemplate = true
        ImageCache.shared.cacheImage(image, forKey: cacheKey)
        return image
    }
}


