import Foundation

/// Protocol for managing notifications.
@MainActor
protocol NotificationManagerProtocol: ObservableObject {
    /// Flag indicating authorization to send notifications.
    var isAuthorized: Bool { get }
    
    /// Requests authorization for notifications.
    func requestAuthorization()
    
    /// Checks current authorization status.
    func checkAuthorizationStatus()
    
    /// Sends VPN status notification.
    /// - Parameters:
    ///   - isConnected: Connection state.
    ///   - connectionName: Connection name (optional).
    func sendVPNNotification(isConnected: Bool, connectionName: String?)
    
    /// Removes all delivered notifications.
    func removeAllDeliveredNotifications()
}


