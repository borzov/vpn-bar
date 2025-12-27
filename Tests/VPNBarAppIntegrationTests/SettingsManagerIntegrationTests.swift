import XCTest
@testable import VPNBarApp

@MainActor
final class SettingsManagerIntegrationTests: XCTestCase {
    var sut: SettingsManager!
    
    override func setUp() {
        super.setUp()
        sut = SettingsManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_updateInterval_persistsInUserDefaults() {
        let testInterval: TimeInterval = 30.0
        let originalInterval = sut.updateInterval
        
        sut.updateInterval = testInterval
        
        let loadedInterval = sut.updateInterval
        XCTAssertEqual(loadedInterval, testInterval)
        
        sut.updateInterval = originalInterval
    }
    
    func test_hotkeyKeyCode_persistsInUserDefaults() {
        let testKeyCode: UInt32 = 12
        let originalKeyCode = sut.hotkeyKeyCode
        
        sut.hotkeyKeyCode = testKeyCode
        
        let loadedKeyCode = sut.hotkeyKeyCode
        XCTAssertEqual(loadedKeyCode, testKeyCode)
        
        sut.hotkeyKeyCode = originalKeyCode
    }
    
    func test_hotkeyModifiers_persistsInUserDefaults() {
        let testModifiers: UInt32 = 256
        let originalModifiers = sut.hotkeyModifiers
        
        sut.hotkeyModifiers = testModifiers
        
        let loadedModifiers = sut.hotkeyModifiers
        XCTAssertEqual(loadedModifiers, testModifiers)
        
        sut.hotkeyModifiers = originalModifiers
    }
    
    func test_showNotifications_persistsInUserDefaults() {
        let originalValue = sut.showNotifications
        
        sut.showNotifications = !originalValue
        
        let loadedValue = sut.showNotifications
        XCTAssertEqual(loadedValue, !originalValue)
        
        sut.showNotifications = originalValue
    }
    
    func test_showConnectionName_persistsInUserDefaults() {
        let originalValue = sut.showConnectionName
        
        sut.showConnectionName = !originalValue
        
        let loadedValue = sut.showConnectionName
        XCTAssertEqual(loadedValue, !originalValue)
        
        sut.showConnectionName = originalValue
    }
    
    func test_saveHotkey_persistsBothValues() {
        let testKeyCode: UInt32 = 12
        let testModifiers: UInt32 = 256
        let originalKeyCode = sut.hotkeyKeyCode
        let originalModifiers = sut.hotkeyModifiers
        
        sut.saveHotkey(keyCode: testKeyCode, modifiers: testModifiers)
        
        XCTAssertEqual(sut.hotkeyKeyCode, testKeyCode)
        XCTAssertEqual(sut.hotkeyModifiers, testModifiers)
        
        sut.saveHotkey(keyCode: originalKeyCode, modifiers: originalModifiers)
    }
}


