import XCTest
@testable import VPNBarApp

final class VPNErrorTests: XCTestCase {
    
    func test_noConfigurations_hasErrorDescription() {
        let error = VPNError.noConfigurations
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
    
    func test_connectionNotFound_hasErrorDescription() {
        let error = VPNError.connectionNotFound(id: "test-id")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test-id") ?? false)
    }
    
    func test_sessionNotFound_hasErrorDescription() {
        let error = VPNError.sessionNotFound(id: "test-id")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test-id") ?? false)
    }
    
    func test_sessionCreationFailed_hasErrorDescription() {
        let error = VPNError.sessionCreationFailed(id: "test-id")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test-id") ?? false)
    }
    
    func test_frameworkLoadFailed_hasErrorDescription() {
        let error = VPNError.frameworkLoadFailed(reason: "test-reason")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("test-reason") ?? false)
    }
    
    func test_connectionFailed_withUnderlying_hasErrorDescription() {
        let error = VPNError.connectionFailed(underlying: "test-error")
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.errorDescription, "test-error")
    }
    
    func test_connectionFailed_withoutUnderlying_hasErrorDescription() {
        let error = VPNError.connectionFailed(underlying: nil)
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
    
    func test_sharedManagerUnavailable_hasErrorDescription() {
        let error = VPNError.sharedManagerUnavailable
        
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }
    
    func test_vpnError_equatable() {
        let error1 = VPNError.noConfigurations
        let error2 = VPNError.noConfigurations
        let error3 = VPNError.connectionNotFound(id: "test")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}


