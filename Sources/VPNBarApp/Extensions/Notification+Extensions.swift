import Foundation

extension Notification.Name {
    /// Notification about hotkey change.
    static let hotkeyDidChange = Notification.Name("HotkeyDidChange")

    /// Notification about update interval change.
    static let updateIntervalDidChange = Notification.Name("UpdateIntervalDidChange")

    /// Notification about connection name display change.
    static let showConnectionNameDidChange = Notification.Name("ShowConnectionNameDidChange")

    /// Notification about VPN connections list change.
    static let vpnConnectionsDidChange = Notification.Name("VPNConnectionsDidChange")
}

