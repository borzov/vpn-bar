import Foundation

/// Интерфейс менеджера уведомлений.
@MainActor
protocol NotificationManagerProtocol: ObservableObject {
    /// Признак разрешения на отправку уведомлений.
    var isAuthorized: Bool { get }
    
    /// Запрашивает разрешение на уведомления.
    func requestAuthorization()
    
    /// Проверяет текущий статус авторизации.
    func checkAuthorizationStatus()
    
    /// Отправляет уведомление о состоянии VPN.
    /// - Parameters:
    ///   - isConnected: Состояние подключения.
    ///   - connectionName: Имя подключения (опционально).
    func sendVPNNotification(isConnected: Bool, connectionName: String?)
    
    /// Удаляет все доставленные уведомления.
    func removeAllDeliveredNotifications()
}


