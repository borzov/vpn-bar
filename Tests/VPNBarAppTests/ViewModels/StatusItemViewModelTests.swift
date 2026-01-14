import XCTest
import Combine
@testable import VPNBarApp

@MainActor
final class StatusItemViewModelTests: XCTestCase {
    var sut: StatusItemViewModel!
    var cancellables: Set<AnyCancellable>!
    var mockVPNManager: MockVPNManager!
    var mockSettingsManager: MockSettingsManager!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockVPNManager = MockVPNManager()
        mockSettingsManager = MockSettingsManager()
        
        sut = StatusItemViewModel(
            vpnManager: mockVPNManager,
            settings: mockSettingsManager
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
        mockVPNManager = nil
        mockSettingsManager = nil
        super.tearDown()
    }
    
    func test_init_withNoConnections_createsDisconnectedState() {
        let expectation = XCTestExpectation(description: "State should be disconnected")
        
        sut.$state
            .sink { state in
                if case .disconnected = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_withConnectedConnection_createsConnectedState() {
        let expectation = XCTestExpectation(description: "State should be connected")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connected(let content) = state {
                    XCTAssertNotNil(content.image)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let connection = VPNConnectionFactory.createConnected()
        mockVPNManager.connections = [connection]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_withConnectingConnection_createsConnectingState() {
        let expectation = XCTestExpectation(description: "State should be connecting")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connecting = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let connection = VPNConnectionFactory.createConnecting()
        mockVPNManager.connections = [connection]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_withDisconnectingConnection_createsConnectingState() {
        let expectation = XCTestExpectation(description: "State should be connecting")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connecting = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let connection = VPNConnectionFactory.createDisconnecting()
        mockVPNManager.connections = [connection]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_whenConnectionChanges_updatesState() {
        let expectation = XCTestExpectation(description: "State should update")
        expectation.expectedFulfillmentCount = 2
        
        sut.$state
            .dropFirst()
            .sink { state in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Set initial state
        let disconnected = VPNConnectionFactory.createDisconnected()
        mockVPNManager.connections = [disconnected]
        
        // Wait for first update (fallback timer updates every 1 second)
        let firstUpdate = XCTestExpectation(description: "First state update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            firstUpdate.fulfill()
        }
        wait(for: [firstUpdate], timeout: 2.0)
        
        // Change to connected state
        let connected = VPNConnectionFactory.createConnected(id: disconnected.id, name: disconnected.name)
        mockVPNManager.connections = [connected]
        
        // Wait for second update
        wait(for: [expectation], timeout: 3.0)
    }
    
    func test_tooltip_withShowConnectionNameEnabled_includesName() {
        mockSettingsManager.showConnectionName = true
        
        let expectation = XCTestExpectation(description: "Tooltip should include name")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connected(let content) = state {
                    XCTAssertEqual(content.toolTip, "My VPN")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        mockVPNManager.connections = [connection]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_tooltip_withShowConnectionNameDisabled_doesNotIncludeName() {
        mockSettingsManager.showConnectionName = false
        
        let expectation = XCTestExpectation(description: "Tooltip should not include name")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connected(let content) = state {
                    XCTAssertNotEqual(content.toolTip, "My VPN")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        mockVPNManager.connections = [connection]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_whenShowConnectionNameChanges_updatesTooltip() {
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        mockVPNManager.connections = [connection]
        mockSettingsManager.showConnectionName = false
        
        let expectation = XCTestExpectation(description: "Tooltip should update")
        expectation.expectedFulfillmentCount = 2
        
        sut.$state
            .dropFirst()
            .sink { state in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.post(name: .showConnectionNameDidChange, object: nil)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_withMultipleConnections_usesFirstActive() {
        mockSettingsManager.showConnectionName = true
        
        let expectation = XCTestExpectation(description: "State should use first active")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connected(let content) = state {
                    XCTAssertNotNil(content.connectionName)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let disconnected = VPNConnectionFactory.createDisconnected(name: "VPN 1")
        let connected = VPNConnectionFactory.createConnected(name: "VPN 2")
        mockVPNManager.connections = [disconnected, connected]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_state_withNoActiveConnections_createsDisconnectedState() {
        let expectation = XCTestExpectation(description: "State should be disconnected")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .disconnected = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let disconnected1 = VPNConnectionFactory.createDisconnected(name: "VPN 1")
        let disconnected2 = VPNConnectionFactory.createDisconnected(name: "VPN 2")
        mockVPNManager.connections = [disconnected1, disconnected2]
        
        wait(for: [expectation], timeout: 2.0)
    }
}

