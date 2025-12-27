import Foundation
import Combine
@testable import VPNBarApp

@MainActor
final class MockVPNManager: VPNManagerProtocol {
    @Published var connections: [VPNConnection] = []
    @Published var hasActiveConnection: Bool = false
    @Published var loadingError: VPNError?
    
    var updateInterval: TimeInterval = 15.0
    
    var loadConnectionsCalled = false
    var loadConnectionsForceReload: Bool?
    var connectCalled = false
    var connectConnectionID: String?
    var disconnectCalled = false
    var disconnectConnectionID: String?
    var toggleConnectionCalled = false
    var toggleConnectionID: String?
    var disconnectAllCalled = false
    
    var loadConnectionsResult: Result<[VPNConnection], Error>?
    var connectShouldSucceed = true
    var disconnectShouldSucceed = true
    
    func loadConnections(forceReload: Bool) {
        loadConnectionsCalled = true
        loadConnectionsForceReload = forceReload
        
        if let result = loadConnectionsResult {
            switch result {
            case .success(let connections):
                self.connections = connections
                self.loadingError = nil
                updateActiveStatus()
            case .failure(let error):
                self.connections = []
                if let vpnError = error as? VPNError {
                    self.loadingError = vpnError
                } else {
                    self.loadingError = .connectionFailed(underlying: error.localizedDescription)
                }
                updateActiveStatus()
            }
        }
    }
    
    func connect(to connectionID: String, retryCount: Int = 3) {
        connectCalled = true
        connectConnectionID = connectionID
        
        if connectShouldSucceed {
            if let index = connections.firstIndex(where: { $0.id == connectionID }) {
                var updatedConnections = connections
                updatedConnections[index].status = .connected
                connections = updatedConnections
                updateActiveStatus()
            }
        }
    }
    
    func disconnect(from connectionID: String) {
        disconnectCalled = true
        disconnectConnectionID = connectionID
        
        if disconnectShouldSucceed {
            if let index = connections.firstIndex(where: { $0.id == connectionID }) {
                var updatedConnections = connections
                updatedConnections[index].status = .disconnected
                connections = updatedConnections
                updateActiveStatus()
            }
        }
    }
    
    func toggleConnection(_ connectionID: String) {
        toggleConnectionCalled = true
        toggleConnectionID = connectionID
        
        if let connection = connections.first(where: { $0.id == connectionID }) {
            if connection.status.isActive {
                disconnect(from: connectionID)
            } else {
                connect(to: connectionID)
            }
        }
    }
    
    func disconnectAll() {
        disconnectAllCalled = true
        let activeConnections = connections.filter { $0.status.isActive }
        for connection in activeConnections {
            disconnect(from: connection.id)
        }
    }
    
    private func updateActiveStatus() {
        hasActiveConnection = connections.contains { $0.status.isActive }
    }
    
    func reset() {
        connections = []
        hasActiveConnection = false
        loadingError = nil
        updateInterval = 15.0
        loadConnectionsCalled = false
        loadConnectionsForceReload = nil
        connectCalled = false
        connectConnectionID = nil
        disconnectCalled = false
        disconnectConnectionID = nil
        toggleConnectionCalled = false
        toggleConnectionID = nil
        disconnectAllCalled = false
        loadConnectionsResult = nil
        connectShouldSucceed = true
        disconnectShouldSucceed = true
    }
}

