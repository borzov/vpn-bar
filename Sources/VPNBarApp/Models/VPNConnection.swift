import Foundation
import SystemConfiguration

/// Модель VPN-подключения, используемая для отображения и управления статусом.
struct VPNConnection: Identifiable, Equatable {
    let id: String
    let name: String
    let serviceID: String
    var status: VPNStatus
    
    /// Текущее состояние VPN-подключения.
    enum VPNStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case disconnecting
        
        /// Возвращает `true`, когда соединение активно или устанавливается.
        var isActive: Bool {
            self == .connected || self == .connecting
        }
    }
    
    static func == (lhs: VPNConnection, rhs: VPNConnection) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

