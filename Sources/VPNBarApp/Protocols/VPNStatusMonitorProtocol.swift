import Foundation
import Combine
import SystemConfiguration

/// Протокол для мониторинга статуса VPN-подключений.
@MainActor
protocol VPNStatusMonitorProtocol {
    /// Издатель статусов подключений.
    var statusPublisher: AnyPublisher<[String: SCNetworkConnectionStatus], Never> { get }
    
    /// Запускает мониторинг статусов.
    func startMonitoring()
    
    /// Останавливает мониторинг статусов.
    func stopMonitoring()
    
    /// Обновляет статус для указанного подключения.
    /// - Parameter connectionID: Идентификатор соединения.
    func refreshStatus(for connectionID: String)
    
    /// Обновляет статусы всех подключений.
    func refreshAllStatuses()
}

