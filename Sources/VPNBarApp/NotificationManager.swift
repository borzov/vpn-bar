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
        // Устанавливаем delegate сразу при инициализации
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// Запрашивает разрешение на уведомления
    /// Для menu bar приложений использует provisional authorization
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        // Устанавливаем delegate ДО запроса авторизации
        center.delegate = self
        
        // Сначала проверяем текущий статус
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Если уже авторизовано, не запрашиваем снова
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.isAuthorized = true
                    return
                }
                
                // Для menu bar apps используем обычную авторизацию (provisional может не работать)
                // Это покажет диалог при первом запуске, но уведомления будут работать надежнее
                let options: UNAuthorizationOptions = [.alert, .sound]
                
                do {
                    let granted = try await center.requestAuthorization(options: options)
                    self.isAuthorized = granted
                    // Обновляем статус после запроса
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
        // Убеждаемся, что delegate установлен
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        Task {
            let content = UNMutableNotificationContent()
            
            if isConnected {
                content.title = NSLocalizedString("VPN Connected", comment: "")
                if let name = connectionName {
                    content.body = String(format: NSLocalizedString("Connected to %@", comment: ""), name)
                } else {
                    content.body = NSLocalizedString("VPN Connected", comment: "")
                }
            } else {
                content.title = NSLocalizedString("VPN Disconnected", comment: "")
                if let name = connectionName {
                    content.body = String(format: NSLocalizedString("Disconnected from %@", comment: ""), name)
                } else {
                    content.body = NSLocalizedString("VPN Disconnected", comment: "")
                }
            }
            
            // Используем default звук
            content.sound = .default
            
            // Категория для возможных действий в будущем
            content.categoryIdentifier = "VPN_STATUS"
            
            // Уникальный идентификатор, чтобы новое уведомление заменяло старое
            let identifier = "vpn-status-\(connectionName ?? "default")"
            
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: nil // Немедленная доставка
            )
            
            do {
                try await center.add(request)
            } catch {
                await MainActor.run {
                    self.logger.error("Failed to deliver notification: \(error.localizedDescription)")
                    // Fallback на старый API для совместимости
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
        // Используем старый API как fallback
        let notification = NSUserNotification()
        
        if isConnected {
            notification.title = NSLocalizedString("VPN Connected", comment: "")
            if let name = connectionName {
                notification.informativeText = String(format: NSLocalizedString("Connected to %@", comment: ""), name)
            }
        } else {
            notification.title = NSLocalizedString("VPN Disconnected", comment: "")
            if let name = connectionName {
                notification.informativeText = String(format: NSLocalizedString("Disconnected from %@", comment: ""), name)
            }
        }
        
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
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

