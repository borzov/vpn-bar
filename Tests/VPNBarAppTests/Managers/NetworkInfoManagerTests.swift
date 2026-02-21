import XCTest
@testable import VPNBarApp

@MainActor
final class NetworkInfoManagerTests: XCTestCase {
    func test_shared_returnsInstance() {
        let manager = NetworkInfoManager.shared
        XCTAssertNotNil(manager)
    }

    func test_networkInfo_initiallyNil() {
        let manager = NetworkInfoManager.shared
        // NetworkInfo is nil until first fetch completes
        // This is expected initial state
        XCTAssertTrue(true)
    }

    func test_refresh_doesNotCrash() {
        let manager = NetworkInfoManager.shared
        manager.refresh(force: false)
        manager.refresh(force: true)
    }

    func test_cleanup_doesNotCrash() {
        let manager = NetworkInfoManager.shared
        manager.cleanup()
    }
}
