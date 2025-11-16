import Foundation
import SystemConfiguration

struct VPNConnection: Identifiable, Equatable {
    let id: String
    let name: String
    let serviceID: String
    var status: VPNStatus
    
    enum VPNStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case disconnecting
        
        var isActive: Bool {
            self == .connected || self == .connecting
        }
    }
    
    static func == (lhs: VPNConnection, rhs: VPNConnection) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

