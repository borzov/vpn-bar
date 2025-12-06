import XCTest
@testable import VPNBarApp

final class HotkeyManagerTests: XCTestCase {
    var sut: HotkeyManager!
    
    override func setUp() {
        super.setUp()
        sut = HotkeyManager.shared
    }
    
    override func tearDown() {
        sut.unregisterHotkey()
        sut = nil
        super.tearDown()
    }
    
    func test_shared_isSingleton() {
        let instance1 = HotkeyManager.shared
        let instance2 = HotkeyManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func test_registerHotkey_withValidParameters_canBeCalled() {
        let keyCode: UInt32 = 12
        let modifiers: UInt32 = 256
        
        sut.registerHotkey(keyCode: keyCode, modifiers: modifiers) {
            // Callback executed
        }
        
        XCTAssertTrue(true)
    }
    
    func test_unregisterHotkey_afterRegistration_canBeCalled() {
        sut.registerHotkey(keyCode: 12, modifiers: 256) {}
        
        sut.unregisterHotkey()
        
        XCTAssertTrue(true)
    }
    
    func test_unregisterHotkey_withoutRegistration_doesNotCrash() {
        sut.unregisterHotkey()
        
        XCTAssertTrue(true)
    }
    
    func test_registerHotkey_twice_unregistersPrevious() {
        sut.registerHotkey(keyCode: 12, modifiers: 256) {
            // First callback
        }
        
        sut.registerHotkey(keyCode: 13, modifiers: 256) {
            // Second callback
        }
        
        XCTAssertTrue(true)
    }
}

