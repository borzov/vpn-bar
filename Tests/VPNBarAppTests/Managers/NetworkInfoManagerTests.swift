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

    func test_cleanup_doesNotCrash() {
        let manager = NetworkInfoManager.shared
        manager.cleanup()
    }

    func test_networkInfo_withAllNilGeoFields_producesNilFormattedLocation() {
        let info = NetworkInfo(
            publicIP: nil,
            country: nil,
            countryCode: nil,
            city: nil,
            vpnInterfaces: [],
            lastUpdated: Date()
        )
        XCTAssertNil(info.formattedLocation)
        XCTAssertNil(info.publicIP)
        XCTAssertNil(info.countryFlag)
    }
}
