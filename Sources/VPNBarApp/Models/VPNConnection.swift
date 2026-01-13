import Foundation
import SystemConfiguration

/// Модель VPN-подключения, используемая для отображения и управления статусом.
struct VPNConnection: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let serviceID: String
    var status: VPNStatus

    /// Текущее состояние VPN-подключения.
    enum VPNStatus: Equatable, Hashable {
        case disconnected
        case connecting
        case connected
        case disconnecting

        /// Возвращает `true`, когда соединение активно или устанавливается.
        var isActive: Bool {
            self == .connected || self == .connecting
        }
    }

    // Full Equatable implementation comparing all fields
    static func == (lhs: VPNConnection, rhs: VPNConnection) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.serviceID == rhs.serviceID &&
        lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(serviceID)
        hasher.combine(status)
    }
}

