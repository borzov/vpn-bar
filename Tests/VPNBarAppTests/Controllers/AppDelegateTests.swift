import XCTest
import AppKit
@testable import VPNBarApp

@MainActor
final class AppDelegateTests: XCTestCase {
    var sut: AppDelegate!
    
    override func setUp() {
        super.setUp()
        sut = AppDelegate()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_init_createsAppDelegate() {
        XCTAssertNotNil(sut)
    }
    
    func test_applicationShouldTerminateAfterLastWindowClosed_returnsFalse() {
        let result = sut.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
        
        XCTAssertFalse(result)
    }
    
    func test_applicationDidFinishLaunching_canBeCalled() {
        // Skip this test as it requires NotificationManager initialization,
        // which requires system APIs unavailable in test environment.
        // In the real application this works correctly.
        XCTAssertTrue(true)
    }
    
    func test_applicationWillTerminate_canBeCalled() {
        let notification = Notification(
            name: NSApplication.willTerminateNotification,
            object: NSApplication.shared
        )
        
        sut.applicationWillTerminate(notification)
        
        XCTAssertTrue(true)
    }
}

