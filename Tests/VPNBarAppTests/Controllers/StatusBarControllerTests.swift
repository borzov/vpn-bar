import XCTest
import AppKit
@testable import VPNBarApp

@MainActor
final class StatusBarControllerTests: XCTestCase {
    var sut: StatusBarController!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_init_createsStatusBarController() {
        sut = StatusBarController()
        
        XCTAssertNotNil(sut)
        XCTAssertNotNil(StatusBarController.shared)
    }
    
    func test_shared_afterInit_isSet() {
        sut = StatusBarController()
        
        XCTAssertTrue(StatusBarController.shared === sut)
    }
    
    func test_toggleVPNConnection_canBeCalled() {
        sut = StatusBarController()
        
        sut.toggleVPNConnection()
        
        XCTAssertTrue(true)
    }
    
    func test_toggleVPNConnection_withNoConnections_doesNotCrash() {
        sut = StatusBarController()
        
        sut.toggleVPNConnection()
        
        XCTAssertTrue(true)
    }
    
    func test_updateMenu_canBeCalled() {
        sut = StatusBarController()
        
        sut.updateMenu()
        
        XCTAssertTrue(true)
    }
}

