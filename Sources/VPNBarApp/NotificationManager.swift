import Foundation
@preconcurrency import UserNotifications
import os.log

/// Управляет запросами и доставкой уведомлений о состоянии VPN.
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Notifications")
    
    /// Признак разрешения на отправку уведомлений.
    @Published private(set) var isAuthorized = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Запрашивает разрешение на уведомления
    /// Для menu bar приложений использует provisional authorization
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
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
    
    /// Проверяет текущий статус авторизации
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                let authorized = settings.authorizationStatus == .authorized || 
                                settings.authorizationStatus == .provisional
                self?.isAuthorized = authorized
            }
        }
    }
    
    /// Отправляет уведомление о подключении/отключении VPN
    func sendVPNNotification(isConnected: Bool, connectionName: String?) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        Task {
            let content = UNMutableNotificationContent()
            
            if isConnected {
                content.title = NSLocalizedString(
                    "notifications.title.connected",
                    comment: "Notification title when VPN connects"
                )
                if let name = connectionName {
                    content.body = String(
                        format: NSLocalizedString(
                            "notifications.body.connectedTo",
                            comment: "Notification body with VPN name on connect"
                        ),
                        name
                    )
                } else {
                    content.body = NSLocalizedString(
                        "notifications.body.connected",
                        comment: "Notification body when VPN connects without name"
                    )
                }
            } else {
                content.title = NSLocalizedString(
                    "notifications.title.disconnected",
                    comment: "Notification title when VPN disconnects"
                )
                if let name = connectionName {
                    content.body = String(
                        format: NSLocalizedString(
                            "notifications.body.disconnectedFrom",
                            comment: "Notification body with VPN name on disconnect"
                        ),
                        name
                    )
                } else {
                    content.body = NSLocalizedString(
                        "notifications.body.disconnected",
                        comment: "Notification body when VPN disconnects without name"
                    )
                }
            }
            
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
    
    /// Удаляет все доставленные уведомления приложения
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    /// Fallback на старый NSUserNotification API для совместимости
    @available(macOS, deprecated: 11.0)
    private func sendLegacyNotification(isConnected: Bool, connectionName: String?) {
        let notification = NSUserNotification()
        
        if isConnected {
            notification.title = NSLocalizedString(
                "notifications.title.connected",
                comment: "Notification title when VPN connects"
            )
            if let name = connectionName {
                notification.informativeText = String(
                    format: NSLocalizedString(
                        "notifications.body.connectedTo",
                        comment: "Notification body with VPN name on connect"
                    ),
                    name
                )
            }
        } else {
            notification.title = NSLocalizedString(
                "notifications.title.disconnected",
                comment: "Notification title when VPN disconnects"
            )
            if let name = connectionName {
                notification.informativeText = String(
                    format: NSLocalizedString(
                        "notifications.body.disconnectedFrom",
                        comment: "Notification body with VPN name on disconnect"
                    ),
                    name
                )
            }
        }
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Позволяет показывать уведомления даже когда приложение активно
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    /// Обрабатывает нажатие на уведомление
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

