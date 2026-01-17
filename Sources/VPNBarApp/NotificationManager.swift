import Foundation
@preconcurrency import UserNotifications
import os.log

/// Manages requests and delivery of VPN status notifications.
@MainActor
class NotificationManager: NSObject, NotificationManagerProtocol {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Notifications")
    
    /// Flag indicating authorization to send notifications.
    @Published private(set) var isAuthorized = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Requests authorization for notifications.
    /// For menu bar applications uses provisional authorization.
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            
            Task { @MainActor in
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.isAuthorized = true
                    return
                }
                
                let options: UNAuthorizationOptions = [.alert, .sound]
                
                do {
                    let granted = try await center.requestAuthorization(options: options)
                    self.isAuthorized = granted
                    self.checkAuthorizationStatus()
                } catch {
                    self.logger.error("Notification authorization error: \(error.localizedDescription)")
                    self.isAuthorized = false
                }
            }
        }
    }
    
    /// Checks current authorization status.
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                let authorized = settings.authorizationStatus == .authorized || 
                                settings.authorizationStatus == .provisional
                self?.isAuthorized = authorized
            }
        }
    }
    
    /// Builds notification content for VPN status change.
    /// - Parameters:
    ///   - isConnected: Connection state.
    ///   - connectionName: Connection name (optional).
    /// - Returns: Tuple with title and body strings.
    private func buildNotificationContent(isConnected: Bool, connectionName: String?) -> (title: String, body: String) {
        let title: String
        let body: String
        
        if isConnected {
            title = NSLocalizedString(
                "notifications.title.connected",
                comment: "Notification title when VPN connects"
            )
            if let name = connectionName {
                body = String(
                    format: NSLocalizedString(
                        "notifications.body.connectedTo",
                        comment: "Notification body with VPN name on connect"
                    ),
                    name
                )
            } else {
                body = NSLocalizedString(
                    "notifications.body.connected",
                    comment: "Notification body when VPN connects without name"
                )
            }
        } else {
            title = NSLocalizedString(
                "notifications.title.disconnected",
                comment: "Notification title when VPN disconnects"
            )
            if let name = connectionName {
                body = String(
                    format: NSLocalizedString(
                        "notifications.body.disconnectedFrom",
                        comment: "Notification body with VPN name on disconnect"
                    ),
                    name
                )
            } else {
                body = NSLocalizedString(
                    "notifications.body.disconnected",
                    comment: "Notification body when VPN disconnects without name"
                )
            }
        }
        
        return (title: title, body: body)
    }
    
    /// Sends notification about VPN connection/disconnection.
    func sendVPNNotification(isConnected: Bool, connectionName: String?) {
        let center = UNUserNotificationCenter.current()
        
        Task {
            let content = UNMutableNotificationContent()
            let notificationContent = buildNotificationContent(isConnected: isConnected, connectionName: connectionName)
            content.title = notificationContent.title
            content.body = notificationContent.body
            
            content.sound = .default
            
            content.categoryIdentifier = "VPN_STATUS"
            
            let identifier = "vpn-status-\(connectionName ?? "default")"
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil
            )
            
            do {
                try await center.add(request)
            } catch {
                await MainActor.run {
                    self.logger.error("Failed to deliver notification: \(error.localizedDescription)")
                    self.sendLegacyNotification(isConnected: isConnected, connectionName: connectionName)
                }
            }
        }
    }
    
    /// Removes all delivered application notifications.
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// Fallback to legacy NSUserNotification API for compatibility.
    @available(macOS, deprecated: 11.0)
    private func sendLegacyNotification(isConnected: Bool, connectionName: String?) {
        let notification = NSUserNotification()
        let notificationContent = buildNotificationContent(isConnected: isConnected, connectionName: connectionName)
        notification.title = notificationContent.title
        notification.informativeText = notificationContent.body
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Allows showing notifications even when application is active.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    /// Handles notification tap.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

