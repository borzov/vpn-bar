import XCTest
import Combine
@testable import VPNBarApp

@MainActor
final class StatusItemViewModelTests: XCTestCase {
    var sut: StatusItemViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        
        sut = StatusItemViewModel(
            vpnManager: VPNManager.shared,
            settings: SettingsManager.shared
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        sut = nil
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
        let connection = VPNConnectionFactory.createConnected()
        VPNManager.shared.connections = [connection]
        
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
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_withConnectingConnection_createsConnectingState() {
        let connection = VPNConnectionFactory.createConnecting()
        VPNManager.shared.connections = [connection]
        
        let expectation = XCTestExpectation(description: "State should be connecting")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connecting = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_withDisconnectingConnection_createsConnectingState() {
        let connection = VPNConnectionFactory.createDisconnecting()
        VPNManager.shared.connections = [connection]
        
        let expectation = XCTestExpectation(description: "State should be connecting")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .connecting = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_whenConnectionChanges_updatesState() {
        let disconnected = VPNConnectionFactory.createDisconnected()
        VPNManager.shared.connections = [disconnected]
        
        let expectation = XCTestExpectation(description: "State should update")
        expectation.expectedFulfillmentCount = 2
        
        sut.$state
            .dropFirst()
            .sink { state in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        let connected = VPNConnectionFactory.createConnected(id: disconnected.id, name: disconnected.name)
        VPNManager.shared.connections = [connected]
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func test_tooltip_withShowConnectionNameEnabled_includesName() {
        SettingsManager.shared.showConnectionName = true
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        VPNManager.shared.connections = [connection]
        
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
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_tooltip_withShowConnectionNameDisabled_doesNotIncludeName() {
        SettingsManager.shared.showConnectionName = false
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        VPNManager.shared.connections = [connection]
        
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
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_whenShowConnectionNameChanges_updatesTooltip() {
        let connection = VPNConnectionFactory.createConnected(name: "My VPN")
        VPNManager.shared.connections = [connection]
        SettingsManager.shared.showConnectionName = false
        
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
        let disconnected = VPNConnectionFactory.createDisconnected(name: "VPN 1")
        let connected = VPNConnectionFactory.createConnected(name: "VPN 2")
        VPNManager.shared.connections = [disconnected, connected]
        
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
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_state_withNoActiveConnections_createsDisconnectedState() {
        let disconnected1 = VPNConnectionFactory.createDisconnected(name: "VPN 1")
        let disconnected2 = VPNConnectionFactory.createDisconnected(name: "VPN 2")
        VPNManager.shared.connections = [disconnected1, disconnected2]
        
        let expectation = XCTestExpectation(description: "State should be disconnected")
        
        sut.$state
            .dropFirst()
            .sink { state in
                if case .disconnected = state {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
}

