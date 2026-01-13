import Foundation

extension Notification.Name {
    /// Уведомление об изменении горячей клавиши.
    static let hotkeyDidChange = Notification.Name("HotkeyDidChange")

    /// Уведомление об изменении интервала обновления.
    static let updateIntervalDidChange = Notification.Name("UpdateIntervalDidChange")

    /// Уведомление об изменении отображения имени подключения.
    static let showConnectionNameDidChange = Notification.Name("ShowConnectionNameDidChange")

    /// Уведомление об изменении списка VPN-подключений.
    static let vpnConnectionsDidChange = Notification.Name("VPNConnectionsDidChange")
}

