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

    private let vpnManager: VPNManager
    private let settings: SettingsManager
    private var cancellables = Set<AnyCancellable>()

    init(vpnManager: VPNManager, settings: SettingsManager) {
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

        vpnManager.$connections
            .combineLatest(showConnectionNameChange)
            .map { connections, _ in
                StatusItemViewModel.makeState(connections: connections, settings: settings)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
            .store(in: &cancellables)
    }

    /// Собирает состояние статус-бара на основе подключений и настроек.
    /// - Parameters:
    ///   - connections: Текущие VPN-подключения.
    ///   - settings: Настройки отображения.
    /// - Returns: Итоговое состояние статус-бара.
    private static func makeState(
        connections: [VPNConnection],
        settings: SettingsManager
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
        guard let image = NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    private static func makeDisconnectedImage() -> NSImage? {
        guard let base = NSImage(systemSymbolName: "network", accessibilityDescription: nil) else {
            return nil
        }
        let image = NSImage(size: base.size)
        image.lockFocus()
        base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 0.4)
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}


