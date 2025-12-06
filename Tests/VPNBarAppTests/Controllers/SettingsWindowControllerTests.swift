import XCTest
import AppKit
@testable import VPNBarApp

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    var sut: SettingsWindowController!
    
    override func setUp() {
        super.setUp()
        sut = SettingsWindowController.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_shared_isSingleton() {
        let instance1 = SettingsWindowController.shared
        let instance2 = SettingsWindowController.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func test_showWindow_canBeCalled() {
        sut.showWindow()
        
        XCTAssertTrue(true)
    }
    
    func test_showWindow_multipleTimes_doesNotCrash() {
        sut.showWindow()
        sut.showWindow()
        sut.showWindow()
        
        XCTAssertTrue(true)
    }
}

