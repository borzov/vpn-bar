import Foundation

extension Notification.Name {
    // Settings changes
    static let hotkeyDidChange = Notification.Name("HotkeyDidChange")
    static let updateIntervalDidChange = Notification.Name("UpdateIntervalDidChange")
    static let showConnectionNameDidChange = Notification.Name("ShowConnectionNameDidChange")
    static let showNotificationsDidChange = Notification.Name("ShowNotificationsDidChange")
    
    // VPN status changes
    static let vpnStatusDidChange = Notification.Name("VPNStatusDidChange")
    static let vpnConnectionsDidLoad = Notification.Name("VPNConnectionsDidLoad")
}

