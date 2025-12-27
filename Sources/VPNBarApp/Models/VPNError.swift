import Foundation

/// Типизированные ошибки VPN-менеджера.
enum VPNError: LocalizedError, Equatable {
    /// Отсутствуют настроенные VPN-конфигурации в системе.
    case noConfigurations
    
    /// Подключение с указанным идентификатором не найдено.
    case connectionNotFound(id: String)
    
    /// Сессия для указанного подключения не найдена.
    case sessionNotFound(id: String)
    
    /// Не удалось создать сессию для подключения.
    case sessionCreationFailed(id: String)
    
    /// Не удалось загрузить NetworkExtension framework.
    case frameworkLoadFailed(reason: String)
    
    /// Ошибка подключения к VPN.
    case connectionFailed(underlying: String?)
    
    /// Shared manager недоступен.
    case sharedManagerUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noConfigurations:
            return NSLocalizedString("error.vpn.noConfigurations", comment: "")
        case .connectionNotFound(let id):
            return String(format: NSLocalizedString("error.vpn.connectionNotFound", comment: ""), id)
        case .sessionNotFound(let id):
            return String(format: NSLocalizedString("error.vpn.sessionNotFound", comment: ""), id)
        case .sessionCreationFailed(let id):
            return String(format: NSLocalizedString("error.vpn.sessionCreateFailed", comment: ""), id)
        case .frameworkLoadFailed(let reason):
            return String(format: NSLocalizedString("error.vpn.loadFrameworkFailed", comment: ""), reason)
        case .connectionFailed(let underlying):
            return underlying ?? NSLocalizedString("error.vpn.connectionFailed", comment: "")
        case .sharedManagerUnavailable:
            return NSLocalizedString("error.vpn.sharedManagerUnavailable", comment: "")
        }
    }
}

