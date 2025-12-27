import XCTest
@testable import VPNBarApp

final class VPNConnectionTests: XCTestCase {
    
    func test_init_withValidData_createsConnection() {
        let id = "test-id"
        let name = "Test VPN"
        let serviceID = "service-id"
        let status = VPNConnection.VPNStatus.connected
        
        let connection = VPNConnection(
            id: id,
            name: name,
            serviceID: serviceID,
            status: status
        )
        
        XCTAssertEqual(connection.id, id)
        XCTAssertEqual(connection.name, name)
        XCTAssertEqual(connection.serviceID, serviceID)
        XCTAssertEqual(connection.status, status)
    }
    
    func test_equatable_withSameIdAndStatus_returnsTrue() {
        let connection1 = VPNConnectionFactory.create(id: "same-id", status: .connected)
        let connection2 = VPNConnectionFactory.create(id: "same-id", status: .connected)
        
        XCTAssertEqual(connection1, connection2)
    }
    
    func test_equatable_withDifferentId_returnsFalse() {
        let connection1 = VPNConnectionFactory.create(id: "id-1", status: .connected)
        let connection2 = VPNConnectionFactory.create(id: "id-2", status: .connected)
        
        XCTAssertNotEqual(connection1, connection2)
    }
    
    func test_equatable_withDifferentStatus_returnsFalse() {
        let connection1 = VPNConnectionFactory.create(id: "same-id", status: .connected)
        let connection2 = VPNConnectionFactory.create(id: "same-id", status: .disconnected)
        
        XCTAssertNotEqual(connection1, connection2)
    }
    
    func test_vpnStatus_isActive_whenConnected_returnsTrue() {
        let status = VPNConnection.VPNStatus.connected
        
        XCTAssertTrue(status.isActive)
    }
    
    func test_vpnStatus_isActive_whenConnecting_returnsTrue() {
        let status = VPNConnection.VPNStatus.connecting
        
        XCTAssertTrue(status.isActive)
    }
    
    func test_vpnStatus_isActive_whenDisconnected_returnsFalse() {
        let status = VPNConnection.VPNStatus.disconnected
        
        XCTAssertFalse(status.isActive)
    }
    
    func test_vpnStatus_isActive_whenDisconnecting_returnsFalse() {
        let status = VPNConnection.VPNStatus.disconnecting
        
        XCTAssertFalse(status.isActive)
    }
    
    func test_vpnStatus_allCases_areDefined() {
        let statuses: [VPNConnection.VPNStatus] = [
            .disconnected,
            .connecting,
            .connected,
            .disconnecting
        ]
        
        XCTAssertEqual(statuses.count, 4)
    }
    
    func test_connection_withEmptyName_isValid() {
        let connection = VPNConnectionFactory.create(name: "")
        
        XCTAssertEqual(connection.name, "")
        XCTAssertFalse(connection.name.isEmpty == false)
    }
    
    func test_connection_withEmptyId_isValid() {
        let connection = VPNConnectionFactory.create(id: "")
        
        XCTAssertEqual(connection.id, "")
    }
    
    func test_connection_mutableStatus_canBeChanged() {
        var connection = VPNConnectionFactory.create(status: .disconnected)
        
        connection.status = .connected
        
        XCTAssertEqual(connection.status, .connected)
    }
    
    func test_connection_identifiable_conformance() {
        let connection = VPNConnectionFactory.create(id: "test-id")
        
        XCTAssertEqual(connection.id, "test-id")
    }
}


