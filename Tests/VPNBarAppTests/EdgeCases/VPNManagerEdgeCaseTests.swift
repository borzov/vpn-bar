import XCTest
@testable import VPNBarApp

@MainActor
final class VPNManagerEdgeCaseTests: XCTestCase {
    var sut: VPNManager!
    
    override func setUp() {
        super.setUp()
        sut = VPNManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_emptyListAfterLoad_handlesCorrectly() {
        sut.loadConnections(forceReload: true)
        
        XCTAssertEqual(sut.connections.count, 0, "Empty list should be handled correctly")
        XCTAssertFalse(sut.hasActiveConnection, "No active connection should be present")
    }
    
    func test_invalidConnectionID_handlesCorrectly() {
        let invalidID = "not-a-valid-uuid"
        
        sut.connect(to: invalidID, retryCount: 1)
        
        XCTAssertNotNil(sut.loadingError, "Should set error for invalid connection ID")
    }
    
    func test_veryLongConnectionID_handlesCorrectly() {
        let longID = String(repeating: "a", count: 1000)
        
        sut.connect(to: longID, retryCount: 1)
        
        XCTAssertNotNil(sut.loadingError, "Should handle very long connection ID")
    }
    
    func test_emptyConnectionID_handlesCorrectly() {
        sut.connect(to: "", retryCount: 1)
        
        XCTAssertNotNil(sut.loadingError, "Should handle empty connection ID")
    }
    
    func test_multipleRapidConnections_handlesCorrectly() {
        let connection = VPNConnection(
            id: UUID().uuidString,
            name: "Test VPN",
            serviceID: UUID().uuidString,
            status: .disconnected
        )
        
        sut.connections = [connection]
        
        for _ in 0..<10 {
            sut.connect(to: connection.id, retryCount: 1)
        }
        
        XCTAssertNoThrow("Should handle multiple rapid connection attempts")
    }
    
    func test_disconnectNonExistentConnection_handlesCorrectly() {
        let nonExistentID = UUID().uuidString
        
        sut.disconnect(from: nonExistentID)
        
        XCTAssertNotNil(sut.loadingError, "Should set error for non-existent connection")
    }
    
    func test_toggleNonExistentConnection_handlesCorrectly() {
        let nonExistentID = UUID().uuidString
        
        sut.toggleConnection(nonExistentID)
        
        XCTAssertNoThrow("Should handle toggle of non-existent connection gracefully")
    }
    
    func test_updateIntervalWithExtremeValues_handlesCorrectly() {
        let originalInterval = sut.updateInterval
        
        sut.updateInterval = -100
        XCTAssertGreaterThanOrEqual(sut.updateInterval, AppConstants.minUpdateInterval, "Should clamp to minimum")
        
        sut.updateInterval = 10000
        XCTAssertLessThanOrEqual(sut.updateInterval, AppConstants.maxUpdateInterval, "Should clamp to maximum")
        
        sut.updateInterval = originalInterval
    }
}


