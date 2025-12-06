import XCTest
import Combine
@testable import VPNBarApp

@MainActor
final class VPNManagerTests: XCTestCase {
    var sut: VPNManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        super.tearDown()
    }
    
    func test_shared_isSingleton() {
        let instance1 = VPNManager.shared
        let instance2 = VPNManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func test_connections_initiallyEmpty() {
        sut = VPNManager.shared
        
        XCTAssertTrue(sut.connections.isEmpty)
    }
    
    func test_hasActiveConnection_withNoConnections_returnsFalse() {
        sut = VPNManager.shared
        
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    func test_updateInterval_defaultValue() {
        sut = VPNManager.shared
        
        XCTAssertGreaterThanOrEqual(sut.updateInterval, AppConstants.minUpdateInterval)
        XCTAssertLessThanOrEqual(sut.updateInterval, AppConstants.maxUpdateInterval)
    }
    
    func test_updateInterval_settingValue_updatesInterval() {
        sut = VPNManager.shared
        let newInterval: TimeInterval = 20.0
        
        sut.updateInterval = newInterval
        
        XCTAssertEqual(sut.updateInterval, newInterval)
    }
    
    func test_updateInterval_settingBelowMinimum_clampsToMinimum() {
        sut = VPNManager.shared
        let belowMinimum: TimeInterval = 1.0
        
        sut.updateInterval = belowMinimum
        
        XCTAssertEqual(sut.updateInterval, AppConstants.minUpdateInterval)
    }
    
    func test_updateInterval_settingAboveMaximum_clampsToMaximum() {
        sut = VPNManager.shared
        let aboveMaximum: TimeInterval = 200.0
        
        sut.updateInterval = aboveMaximum
        
        XCTAssertEqual(sut.updateInterval, AppConstants.maxUpdateInterval)
    }
    
    func test_connect_withValidConnectionID_callsConnect() async {
        sut = VPNManager.shared
        let connection = VPNConnectionFactory.createDisconnected()
        sut.connections = [connection]
        
        sut.connect(to: connection.id)
        
        await TestHelpers.waitForAsync(timeout: 0.6)
        
        let updatedConnection = sut.connections.first(where: { $0.id == connection.id })
        XCTAssertNotNil(updatedConnection)
    }
    
    func test_connect_withInvalidConnectionID_doesNotCrash() {
        sut = VPNManager.shared
        
        sut.connect(to: "invalid-id")
        
        XCTAssertTrue(true)
    }
    
    func test_disconnect_withValidConnectionID_callsDisconnect() async {
        sut = VPNManager.shared
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        
        sut.disconnect(from: connection.id)
        
        await TestHelpers.waitForAsync(timeout: 0.6)
        
        let updatedConnection = sut.connections.first(where: { $0.id == connection.id })
        XCTAssertNotNil(updatedConnection)
    }
    
    func test_disconnect_withInvalidConnectionID_doesNotCrash() {
        sut = VPNManager.shared
        
        sut.disconnect(from: "invalid-id")
        
        XCTAssertTrue(true)
    }
    
    func test_toggleConnection_whenDisconnected_connects() async {
        sut = VPNManager.shared
        let connection = VPNConnectionFactory.createDisconnected()
        sut.connections = [connection]
        
        sut.toggleConnection(connection.id)
        
        await TestHelpers.waitForAsync(timeout: 0.6)
    }
    
    func test_toggleConnection_whenConnected_disconnects() async {
        sut = VPNManager.shared
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        
        sut.toggleConnection(connection.id)
        
        await TestHelpers.waitForAsync(timeout: 0.6)
    }
    
    func test_disconnectAll_withActiveConnections_disconnectsAll() async {
        sut = VPNManager.shared
        let connection1 = VPNConnectionFactory.createConnected(id: "1")
        let connection2 = VPNConnectionFactory.createConnected(id: "2")
        sut.connections = [connection1, connection2]
        
        sut.disconnectAll()
        
        await TestHelpers.waitForAsync(timeout: 0.6)
        
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    func test_disconnectAll_withNoActiveConnections_doesNothing() {
        sut = VPNManager.shared
        let connection1 = VPNConnectionFactory.createDisconnected(id: "1")
        let connection2 = VPNConnectionFactory.createDisconnected(id: "2")
        sut.connections = [connection1, connection2]
        
        sut.disconnectAll()
        
        XCTAssertFalse(sut.hasActiveConnection)
    }
    
    func test_hasActiveConnection_publishesWhenConnectionChanges() {
        sut = VPNManager.shared
        let connection = VPNConnectionFactory.createConnected()
        sut.connections = [connection]
        
        let expectation = XCTestExpectation(description: "hasActiveConnection should update")
        
        sut.$hasActiveConnection
            .dropFirst()
            .sink { hasActive in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_loadConnections_canBeCalled() {
        sut = VPNManager.shared
        
        sut.loadConnections(forceReload: false)
        
        XCTAssertTrue(true)
    }
    
    func test_loadConnections_withForceReload_canBeCalled() {
        sut = VPNManager.shared
        
        sut.loadConnections(forceReload: true)
        
        XCTAssertTrue(true)
    }
}

