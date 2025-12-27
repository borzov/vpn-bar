import XCTest
@testable import VPNBarApp

final class VPNConnectionEdgeCaseTests: XCTestCase {
    func test_veryLongName_isStoredCorrectly() {
        let longName = String(repeating: "A", count: 10000)
        let connection = VPNConnection(
            id: "test-id",
            name: longName,
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.name, longName, "Should store very long name")
        XCTAssertEqual(connection.name.count, 10000, "Name length should be correct")
    }
    
    func test_emptyName_isStoredCorrectly() {
        let connection = VPNConnection(
            id: "test-id",
            name: "",
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.name, "", "Should store empty name")
    }
    
    func test_specialCharactersInName_isStoredCorrectly() {
        let specialName = "VPN!@#$%^&*()_+-=[]{}|;':\",./<>?~`"
        let connection = VPNConnection(
            id: "test-id",
            name: specialName,
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.name, specialName, "Should store name with special characters")
    }
    
    func test_unicodeCharactersInName_isStoredCorrectly() {
        let unicodeName = "VPN名称🚀🔒测试"
        let connection = VPNConnection(
            id: "test-id",
            name: unicodeName,
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.name, unicodeName, "Should store Unicode name")
    }
    
    func test_whitespaceOnlyName_isStoredCorrectly() {
        let whitespaceName = "   \n\t   "
        let connection = VPNConnection(
            id: "test-id",
            name: whitespaceName,
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.name, whitespaceName, "Should store whitespace-only name")
    }
    
    func test_allStatusValues_areValid() {
        let statuses: [VPNConnection.VPNStatus] = [.connected, .connecting, .disconnecting, .disconnected]
        
        for status in statuses {
            let connection = VPNConnection(
                id: "test-id",
                name: "Test",
                serviceID: "test-service",
                status: status
            )
            
            XCTAssertEqual(connection.status, status, "Should store status correctly: \(status)")
        }
    }
    
    func test_veryLongID_isStoredCorrectly() {
        let longID = String(repeating: "a", count: 1000)
        let connection = VPNConnection(
            id: longID,
            name: "Test",
            serviceID: "test-service",
            status: .connected
        )
        
        XCTAssertEqual(connection.id, longID, "Should store very long ID")
    }
}


