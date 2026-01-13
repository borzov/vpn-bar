import Foundation
import SystemConfiguration
@testable import VPNBarApp

@MainActor
final class MockVPNSessionManager: VPNSessionManagerProtocol {
    var getOrCreateSessionCalled = false
    var startConnectionCalled = false
    var stopConnectionCalled = false
    var cleanupCalled = false

    var startConnectionIDs: [String] = []
    var stopConnectionIDs: [String] = []

    var statusToReturn: SCNetworkConnectionStatus = .disconnected
    var shouldThrowOnStart = false
    var shouldThrowOnStop = false

    private var sessions: Set<String> = []
    private var cachedStatuses: [String: SCNetworkConnectionStatus] = [:]

    var allConnectionIDs: [String] {
        Array(sessions)
    }

    func getOrCreateSession(for uuid: NSUUID) async {
        getOrCreateSessionCalled = true
        sessions.insert(uuid.uuidString)
    }

    func startConnection(connectionID: String) throws {
        startConnectionCalled = true
        startConnectionIDs.append(connectionID)

        if shouldThrowOnStart {
            throw VPNError.connectionFailed(underlying: "Mock error")
        }

        cachedStatuses[connectionID] = .connected
    }

    func stopConnection(connectionID: String) throws {
        stopConnectionCalled = true
        stopConnectionIDs.append(connectionID)

        if shouldThrowOnStop {
            throw VPNError.connectionFailed(underlying: "Mock stop error")
        }

        cachedStatuses[connectionID] = .disconnected
    }

    func getSessionStatus(connectionID: String, completion: @escaping (SCNetworkConnectionStatus) -> Void) {
        completion(cachedStatuses[connectionID] ?? statusToReturn)
    }

    func hasSession(for connectionID: String) -> Bool {
        sessions.contains(connectionID)
    }

    func getCachedStatus(for connectionID: String) -> SCNetworkConnectionStatus {
        cachedStatuses[connectionID] ?? .invalid
    }

    func cleanup() {
        cleanupCalled = true
        sessions.removeAll()
        cachedStatuses.removeAll()
    }

    func reset() {
        getOrCreateSessionCalled = false
        startConnectionCalled = false
        stopConnectionCalled = false
        cleanupCalled = false
        startConnectionIDs = []
        stopConnectionIDs = []
        statusToReturn = .disconnected
        shouldThrowOnStart = false
        shouldThrowOnStop = false
        sessions.removeAll()
        cachedStatuses.removeAll()
    }
}
