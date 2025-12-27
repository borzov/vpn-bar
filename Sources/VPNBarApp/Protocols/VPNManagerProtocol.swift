import Foundation
import Combine

/// Интерфейс менеджера VPN-соединений.
@MainActor
protocol VPNManagerProtocol: ObservableObject {
    /// Список доступных соединений.
    var connections: [VPNConnection] { get }
    
    /// Флаг наличия активного соединения.
    var hasActiveConnection: Bool { get }
    
    /// Последняя ошибка загрузки списка соединений.
    var loadingError: VPNError? { get }
    
    /// Интервал обновления состояния соединений.
    var updateInterval: TimeInterval { get set }
    
    /// Загружает или перезагружает список доступных соединений.
    /// - Parameter forceReload: Принудительно перезагрузить независимо от кэша.
    func loadConnections(forceReload: Bool)
    
    /// Инициирует подключение к указанному соединению.
    /// - Parameters:
    ///   - connectionID: Идентификатор соединения.
    ///   - retryCount: Количество попыток подключения (по умолчанию 3).
    func connect(to connectionID: String, retryCount: Int)
    
    /// Отключает указанное соединение.
    /// - Parameter connectionID: Идентификатор соединения.
    func disconnect(from connectionID: String)
    
    /// Переключает состояние соединения (подключить/отключить).
    /// - Parameter connectionID: Идентификатор соединения.
    func toggleConnection(_ connectionID: String)
    
    /// Отключает все активные соединения.
    func disconnectAll()
}

