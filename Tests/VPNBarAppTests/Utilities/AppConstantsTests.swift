import XCTest
@testable import VPNBarApp

final class AppConstantsTests: XCTestCase {
    
    func test_bundleIdentifier_isNotEmpty() {
        XCTAssertFalse(AppConstants.bundleIdentifier.isEmpty)
    }
    
    func test_appName_isNotEmpty() {
        XCTAssertFalse(AppConstants.appName.isEmpty)
    }
    
    func test_appVersion_isNotEmpty() {
        XCTAssertFalse(AppConstants.appVersion.isEmpty)
    }
    
    func test_buildNumber_isNotEmpty() {
        XCTAssertFalse(AppConstants.buildNumber.isEmpty)
    }
    
    func test_minUpdateInterval_isPositive() {
        XCTAssertGreaterThan(AppConstants.minUpdateInterval, 0)
    }
    
    func test_maxUpdateInterval_isGreaterThanMin() {
        XCTAssertGreaterThan(AppConstants.maxUpdateInterval, AppConstants.minUpdateInterval)
    }
    
    func test_defaultUpdateInterval_isBetweenMinAndMax() {
        XCTAssertGreaterThanOrEqual(AppConstants.defaultUpdateInterval, AppConstants.minUpdateInterval)
        XCTAssertLessThanOrEqual(AppConstants.defaultUpdateInterval, AppConstants.maxUpdateInterval)
    }
    
    func test_sessionStatusUpdateInterval_isPositive() {
        XCTAssertGreaterThan(AppConstants.sessionStatusUpdateInterval, 0)
    }
    
    func test_minUpdateInterval_hasReasonableValue() {
        XCTAssertGreaterThanOrEqual(AppConstants.minUpdateInterval, 5.0)
    }
    
    func test_maxUpdateInterval_hasReasonableValue() {
        XCTAssertLessThanOrEqual(AppConstants.maxUpdateInterval, 300.0)
    }
}


