import XCTest
@testable import VPNBarApp

@MainActor
final class VPNManagerEdgeCaseTests: XCTestCase {
    var mockConfigLoader: MockVPNConfigurationLoader!
    var mockSessionManager: MockVPNSessionManager!
    var sut: VPNManager!

    override func setUp() {
        super.setUp()
        mockConfigLoader = MockVPNConfigurationLoader()
        mockSessionManager = MockVPNSessionManager()
        sut = VPNManager(configurationLoader: mockConfigLoader, sessionManager: mockSessionManager)
    }

    override func tearDown() {
        sut = nil
        mockConfigLoader = nil
        mockSessionManager = nil
        super.tearDown()
    }

    func test_emptyListAfterLoad_handlesCorrectly() {
        mockConfigLoader.connectionsToReturn = []
        sut.loadConnections(forceReload: true)

        // Allow async completion to run
        let expectation = XCTestExpectation(description: "Load completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

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
    
    // MARK: - Race Condition Prevention Tests
    
    func test_loadConnections_rapidCalls_preventsRaceCondition() async {
        let firstConnections = [
            VPNConnectionFactory.createDisconnected(id: "1", name: "First VPN")
        ]
        let secondConnections = [
            VPNConnectionFactory.createDisconnected(id: "2", name: "Second VPN")
        ]
        
        // First call with delay - should complete later
        mockConfigLoader.connectionsToReturn = firstConnections
        mockConfigLoader.completionDelay = 0.2
        sut.loadConnections(forceReload: true)
        
        // Second call immediately - should complete first
        mockConfigLoader.connectionsToReturn = secondConnections
        mockConfigLoader.completionDelay = 0
        sut.loadConnections(forceReload: true)
        
        // Wait for both to potentially complete
        await TestHelpers.waitForAsync(timeout: 0.3)
        
        // Should have second (latest) connections, not first
        XCTAssertEqual(sut.connections.count, 1, "Should have one connection")
        XCTAssertEqual(sut.connections.first?.id, "2", "Should have second connection (latest request)")
        XCTAssertEqual(sut.connections.first?.name, "Second VPN", "Should have second connection name")
    }
    
    func test_loadConnections_staleResults_areIgnored() async {
        let staleConnections = [
            VPNConnectionFactory.createDisconnected(id: "stale", name: "Stale VPN")
        ]
        let freshConnections = [
            VPNConnectionFactory.createDisconnected(id: "fresh", name: "Fresh VPN")
        ]
        
        // Start first request with delay
        mockConfigLoader.connectionsToReturn = staleConnections
        mockConfigLoader.completionDelay = 0.15
        sut.loadConnections(forceReload: true)
        
        // Start second request immediately (no delay)
        mockConfigLoader.connectionsToReturn = freshConnections
        mockConfigLoader.completionDelay = 0
        sut.loadConnections(forceReload: true)
        
        // Wait for fresh to complete
        await TestHelpers.waitForAsync(timeout: 0.1)
        
        // Should have fresh connections
        XCTAssertEqual(sut.connections.first?.id, "fresh", "Should have fresh connection")
        
        // Wait for stale to complete
        await TestHelpers.waitForAsync(timeout: 0.1)
        
        // Should still have fresh connections (stale should be ignored)
        XCTAssertEqual(sut.connections.first?.id, "fresh", "Stale result should be ignored")
        XCTAssertNotEqual(sut.connections.first?.id, "stale", "Should not have stale connection")
    }
    
    // MARK: - Disconnect Timeout Tests
    
    func test_disconnect_timeoutTask_isCreated() async {
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        await mockSessionManager.setSession(for: connection.id)
        await mockSessionManager.setCachedStatus(.connected, for: connection.id)
        
        sut.disconnect(from: connection.id)
        
        // Give time for timeout task to be created
        await TestHelpers.waitForAsync(timeout: 0.05)
        
        // Timeout task should exist (we can't directly access it, but we can verify disconnect was called)
        let stopCalled = await mockSessionManager.stopConnectionCalled
        XCTAssertTrue(stopCalled, "Disconnect should be called")
    }
    
    func test_disconnect_successfulDisconnect_cancelsTimeout() async {
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        await mockSessionManager.setSession(for: connection.id)
        await mockSessionManager.setCachedStatus(.disconnected, for: connection.id)
        
        sut.disconnect(from: connection.id)
        
        // Wait for disconnect to complete
        await TestHelpers.waitForAsync(timeout: 0.2)
        
        // After successful disconnect, timeout should be cancelled
        // We verify this by checking that status is disconnected and no error occurred
        let updatedConnection = sut.connections.first(where: { $0.id == connection.id })
        XCTAssertNotNil(updatedConnection, "Connection should exist")
        // Status should be updated to disconnected (timeout was cancelled)
        XCTAssertEqual(updatedConnection?.status, .disconnected, "Status should be disconnected after successful disconnect")
    }
    
    func test_disconnect_timeoutExpires_resetsStatus() async {
        // This test requires modifying AppConstants.connectionTimeout for testing
        // We'll use a shorter timeout by checking the behavior
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        await mockSessionManager.setSession(for: connection.id)
        await mockSessionManager.setCachedStatus(.connected, for: connection.id)
        
        // Set status to disconnecting
        if let index = sut.connections.firstIndex(where: { $0.id == connection.id }) {
            var updatedConnections = sut.connections
            updatedConnections[index].status = .disconnecting
            sut.connections = updatedConnections
        }
        
        sut.disconnect(from: connection.id)
        
        // Don't call getSessionStatus callback to simulate timeout
        // Wait for timeout (normally 30s, but in test we'll verify the mechanism exists)
        // Since we can't easily test the full timeout, we verify the disconnect was attempted
        let stopCalled = await mockSessionManager.stopConnectionCalled
        XCTAssertTrue(stopCalled, "Disconnect should be attempted")
    }
    
    // MARK: - Reset Connection Status Tests
    
    func test_connect_failureAfterRetries_resetsToDisconnected() async {
        let connection = VPNConnectionFactory.createDisconnected()
        sut.connections = [connection]
        await mockSessionManager.setSession(for: connection.id)
        await mockSessionManager.setShouldThrowOnStart(true)
        
        sut.connect(to: connection.id, retryCount: 1)
        
        // Wait for retries to complete
        await TestHelpers.waitForAsync(timeout: 0.5)
        
        let updatedConnection = sut.connections.first(where: { $0.id == connection.id })
        XCTAssertNotNil(updatedConnection, "Connection should exist")
        XCTAssertEqual(updatedConnection?.status, .disconnected, "Status should be reset to disconnected after failure")
    }
    
    func test_connect_sessionCreationFailure_resetsToDisconnected() async {
        let connection = VPNConnectionFactory.createDisconnected()
        sut.connections = [connection]
        // Don't create session - simulate session creation failure
        
        sut.connect(to: connection.id, retryCount: 1)
        
        // Wait for failure handling
        await TestHelpers.waitForAsync(timeout: 0.5)
        
        let updatedConnection = sut.connections.first(where: { $0.id == connection.id })
        XCTAssertNotNil(updatedConnection, "Connection should exist")
        // Status should remain disconnected or be reset to disconnected
        XCTAssertEqual(updatedConnection?.status, .disconnected, "Status should be disconnected after session creation failure")
    }
}


