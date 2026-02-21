import Foundation
@testable import VPNBarApp

@MainActor
final class MockNetworkInfoManager: NetworkInfoManagerProtocol {
    var networkInfo: NetworkInfo?
    var refreshCalled = false
    var refreshForce = false
    var cleanupCalled = false

    func refresh(force: Bool) {
        refreshCalled = true
        refreshForce = force
    }

    func cleanup() {
        cleanupCalled = true
    }

    func reset() {
        networkInfo = nil
        refreshCalled = false
        refreshForce = false
        cleanupCalled = false
    }
}
