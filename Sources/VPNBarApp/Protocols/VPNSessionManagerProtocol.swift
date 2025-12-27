import Foundation
import SystemConfiguration

/// Протокол для управления VPN-сессиями.
@MainActor
protocol VPNSessionManagerProtocol {
    /// Получает или создаёт сессию для указанного UUID.
    /// - Parameter uuid: UUID подключения.
    func getOrCreateSession(for uuid: NSUUID) async
    
    /// Запускает подключение для указанного идентификатора.
    /// - Parameter connectionID: Идентификатор соединения.
    func startConnection(connectionID: String) throws
    
    /// Останавливает подключение для указанного идентификатора.
    /// - Parameter connectionID: Идентификатор соединения.
    func stopConnection(connectionID: String) throws
    
    /// Получает статус сессии.
    /// - Parameter connectionID: Идентификатор соединения.
    /// - Parameter completion: Обработчик результата.
    func getSessionStatus(connectionID: String, completion: @escaping (SCNetworkConnectionStatus) -> Void)
    
    /// Проверяет наличие сессии для указанного соединения.
    /// - Parameter connectionID: Идентификатор соединения.
    /// - Returns: `true` если сессия существует, иначе `false`.
    func hasSession(for connectionID: String) -> Bool
    
    /// Получает кэшированный статус для указанного соединения.
    /// - Parameter connectionID: Идентификатор соединения.
    /// - Returns: Кэшированный статус соединения.
    func getCachedStatus(for connectionID: String) -> SCNetworkConnectionStatus
    
    /// Возвращает список всех идентификаторов соединений, для которых есть сессии.
    var allConnectionIDs: [String] { get }
}

