import Foundation
@testable import VPNBarApp

enum VPNConnectionFactory {
    static func create(
        id: String = UUID().uuidString,
        name: String = "Test VPN",
        serviceID: String? = nil,
        status: VPNConnection.VPNStatus = .disconnected
    ) -> VPNConnection {
        VPNConnection(
            id: id,
            name: name,
            serviceID: serviceID ?? id,
            status: status
        )
    }
    
    static func createConnected(id: String = UUID().uuidString, name: String = "Connected VPN") -> VPNConnection {
        create(id: id, name: name, status: .connected)
    }
    
    static func createDisconnected(id: String = UUID().uuidString, name: String = "Disconnected VPN") -> VPNConnection {
        create(id: id, name: name, status: .disconnected)
    }
    
    static func createConnecting(id: String = UUID().uuidString, name: String = "Connecting VPN") -> VPNConnection {
        create(id: id, name: name, status: .connecting)
    }
    
    static func createDisconnecting(id: String = UUID().uuidString, name: String = "Disconnecting VPN") -> VPNConnection {
        create(id: id, name: name, status: .disconnecting)
    }
    
    static func createMultiple(count: Int, status: VPNConnection.VPNStatus = .disconnected) -> [VPNConnection] {
        (0..<count).map { index in
            create(
                id: "connection-\(index)",
                name: "VPN \(index + 1)",
                status: status
            )
        }
    }
    
    static func createMixed(count: Int) -> [VPNConnection] {
        let statuses: [VPNConnection.VPNStatus] = [.connected, .disconnected, .connecting, .disconnecting]
        return (0..<count).map { index in
            let status = statuses[index % statuses.count]
            return create(
                id: "connection-\(index)",
                name: "VPN \(index + 1)",
                status: status
            )
        }
    }
}


