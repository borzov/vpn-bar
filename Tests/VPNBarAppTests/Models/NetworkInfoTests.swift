import XCTest
@testable import VPNBarApp

final class NetworkInfoTests: XCTestCase {
    func test_countryFlag_validCode_returnsFlag() {
        let info = makeNetworkInfo(countryCode: "US")
        XCTAssertEqual(info.countryFlag, "🇺🇸")
    }

    func test_countryFlag_lowercaseCode_returnsFlag() {
        let info = makeNetworkInfo(countryCode: "gb")
        XCTAssertEqual(info.countryFlag, "🇬🇧")
    }

    func test_countryFlag_nilCode_returnsNil() {
        let info = makeNetworkInfo(countryCode: nil)
        XCTAssertNil(info.countryFlag)
    }

    func test_countryFlag_invalidLength_returnsNil() {
        let info = makeNetworkInfo(countryCode: "USA")
        XCTAssertNil(info.countryFlag)
    }

    func test_formattedLocation_countryAndCity() {
        let info = makeNetworkInfo(country: "United States", countryCode: "US", city: "New York")
        XCTAssertEqual(info.formattedLocation, "🇺🇸 United States, New York")
    }

    func test_formattedLocation_countryOnly() {
        let info = makeNetworkInfo(country: "Germany", countryCode: "DE", city: nil)
        XCTAssertEqual(info.formattedLocation, "🇩🇪 Germany")
    }

    func test_formattedLocation_nilCountry_returnsNil() {
        let info = makeNetworkInfo(country: nil)
        XCTAssertNil(info.formattedLocation)
    }

    func test_formattedLocation_countryWithoutCode() {
        let info = makeNetworkInfo(country: "Test", countryCode: nil, city: "City")
        XCTAssertEqual(info.formattedLocation, "Test, City")
    }

    func test_vpnInterface_equality() {
        let a = VPNInterface(name: "utun2", address: "10.0.0.1")
        let b = VPNInterface(name: "utun2", address: "10.0.0.1")
        XCTAssertEqual(a, b)
    }

    func test_vpnInterface_inequality() {
        let a = VPNInterface(name: "utun2", address: "10.0.0.1")
        let b = VPNInterface(name: "utun3", address: "10.0.0.2")
        XCTAssertNotEqual(a, b)
    }

    func test_networkInfo_equality() {
        let date = Date()
        let a = makeNetworkInfo(ip: "1.2.3.4", date: date)
        let b = makeNetworkInfo(ip: "1.2.3.4", date: date)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeNetworkInfo(
        ip: String? = "1.2.3.4",
        country: String? = "Test",
        countryCode: String? = "TE",
        city: String? = nil,
        vpnInterfaces: [VPNInterface] = [],
        date: Date = Date()
    ) -> NetworkInfo {
        NetworkInfo(
            publicIP: ip,
            country: country,
            countryCode: countryCode,
            city: city,
            vpnInterfaces: vpnInterfaces,
            lastUpdated: date
        )
    }
}
