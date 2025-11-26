import Foundation
@preconcurrency import UserNotifications
import os.log

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Notifications")
    @Published private(set) var isAuthorized = false
    
    private override init() {
        super.init()
    }
    
    /// Запрашивает разрешение на уведомления
    /// Для menu bar приложений использует provisional authorization
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Для menu bar apps лучше использовать provisional - не показывает диалог,
        // но уведомления будут доставляться в Notification Center тихо
        let options: UNAuthorizationOptions = [.alert, .sound, .provisional]
        
        center.requestAuthorization(options: options) { [weak self] granted, error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Notification authorization error: \(error.localizedDescription)")
                }
                self?.isAuthorized = granted
                self?.logger.info("Notification authorization: \(granted)")
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
        guard isAuthorized else {
            logger.warning("Notifications not authorized, skipping")
            return
        }
        
        let content = UNMutableNotificationContent()
        
        if isConnected {
            content.title = NSLocalizedString("VPN Connected", comment: "")
            if let name = connectionName {
                content.body = String(format: NSLocalizedString("Connected to %@", comment: ""), name)
            }
        } else {
            content.title = NSLocalizedString("VPN Disconnected", comment: "")
            if let name = connectionName {
                content.body = String(format: NSLocalizedString("Disconnected from %@", comment: ""), name)
            }
        }
        
        // Используем default звук
        content.sound = .default
        
        // Категория для возможных действий в будущем
        content.categoryIdentifier = "VPN_STATUS"
        
        // Уникальный идентификатор, чтобы новое уведомление заменяло старое
        let identifier = "vpn-status-\(connectionName ?? "default")"
        
        // Сохраняем title в локальную переменную для использования в замыкании
        let notificationTitle = content.title
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Немедленная доставка
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                self?.logger.info("Notification delivered: \(notificationTitle)")
            }
        }
    }
    
    /// Удаляет все доставленные уведомления приложения
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Позволяет показывать уведомления даже когда приложение активно
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Показываем banner и воспроизводим звук даже если приложение активно
        completionHandler([.banner, .sound])
    }
    
    /// Обрабатывает нажатие на уведомление
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Можно добавить обработку действий в будущем
        completionHandler()
    }
}

