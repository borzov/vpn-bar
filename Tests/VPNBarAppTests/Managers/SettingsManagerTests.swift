import XCTest
@testable import VPNBarApp

@MainActor
final class SettingsManagerTests: XCTestCase {
    var sut: SettingsManager!
    var testUserDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")
        testUserDefaults.removePersistentDomain(forName: "test.\(UUID().uuidString)")
        sut = SettingsManager.shared
    }
    
    override func tearDown() {
        testUserDefaults = nil
        sut = nil
        super.tearDown()
    }
    
    func test_shared_isSingleton() {
        let instance1 = SettingsManager.shared
        let instance2 = SettingsManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func test_updateInterval_defaultValue() {
        XCTAssertEqual(sut.updateInterval, AppConstants.defaultUpdateInterval)
    }
    
    func test_updateInterval_settingValue_savesAndLoads() {
        let newInterval: TimeInterval = 25.0
        
        sut.updateInterval = newInterval
        
        XCTAssertEqual(sut.updateInterval, newInterval)
    }
    
    func test_updateInterval_settingBelowMinimum_clampsToMinimum() {
        let belowMinimum: TimeInterval = 1.0
        
        sut.updateInterval = belowMinimum
        
        XCTAssertEqual(sut.updateInterval, AppConstants.minUpdateInterval)
    }
    
    func test_updateInterval_settingAboveMaximum_clampsToMaximum() {
        let aboveMaximum: TimeInterval = 200.0
        
        sut.updateInterval = aboveMaximum
        
        XCTAssertEqual(sut.updateInterval, AppConstants.maxUpdateInterval)
    }
    
    func test_updateInterval_settingValue_postsNotification() {
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        NotificationCenter.default.addObserver(
            forName: .updateIntervalDidChange,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        sut.updateInterval = 20.0
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_hotkeyKeyCode_initiallyNil() {
        XCTAssertNil(sut.hotkeyKeyCode)
    }
    
    func test_hotkeyKeyCode_settingValue_savesAndLoads() {
        let keyCode: UInt32 = 12
        
        sut.hotkeyKeyCode = keyCode
        
        XCTAssertEqual(sut.hotkeyKeyCode, keyCode)
    }
    
    func test_hotkeyKeyCode_settingNil_removesValue() {
        sut.hotkeyKeyCode = 12
        sut.hotkeyKeyCode = nil
        
        XCTAssertNil(sut.hotkeyKeyCode)
    }
    
    func test_hotkeyKeyCode_settingValue_postsNotification() {
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        sut.hotkeyKeyCode = 12
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_hotkeyModifiers_initiallyNil() {
        XCTAssertNil(sut.hotkeyModifiers)
    }
    
    func test_hotkeyModifiers_settingValue_savesAndLoads() {
        let modifiers: UInt32 = 256
        
        sut.hotkeyModifiers = modifiers
        
        XCTAssertEqual(sut.hotkeyModifiers, modifiers)
    }
    
    func test_hotkeyModifiers_settingNil_removesValue() {
        sut.hotkeyModifiers = 256
        sut.hotkeyModifiers = nil
        
        XCTAssertNil(sut.hotkeyModifiers)
    }
    
    func test_hotkeyModifiers_settingValue_postsNotification() {
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        sut.hotkeyModifiers = 256
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_saveHotkey_savesBothKeyCodeAndModifiers() {
        let keyCode: UInt32 = 12
        let modifiers: UInt32 = 256
        
        sut.saveHotkey(keyCode: keyCode, modifiers: modifiers)
        
        XCTAssertEqual(sut.hotkeyKeyCode, keyCode)
        XCTAssertEqual(sut.hotkeyModifiers, modifiers)
    }
    
    func test_saveHotkey_withNilValues_removesBoth() {
        sut.hotkeyKeyCode = 12
        sut.hotkeyModifiers = 256
        
        sut.saveHotkey(keyCode: nil, modifiers: nil)
        
        XCTAssertNil(sut.hotkeyKeyCode)
        XCTAssertNil(sut.hotkeyModifiers)
    }
    
    func test_showNotifications_defaultValue() {
        XCTAssertTrue(sut.showNotifications)
    }
    
    func test_showNotifications_settingValue_savesAndLoads() {
        sut.showNotifications = false
        
        XCTAssertFalse(sut.showNotifications)
        
        sut.showNotifications = true
        
        XCTAssertTrue(sut.showNotifications)
    }
    
    func test_showConnectionName_defaultValue() {
        XCTAssertFalse(sut.showConnectionName)
    }
    
    func test_showConnectionName_settingValue_savesAndLoads() {
        sut.showConnectionName = true
        
        XCTAssertTrue(sut.showConnectionName)
        
        sut.showConnectionName = false
        
        XCTAssertFalse(sut.showConnectionName)
    }
    
    func test_showConnectionName_settingValue_postsNotification() {
        let expectation = XCTestExpectation(description: "Notification should be posted")
        
        NotificationCenter.default.addObserver(
            forName: .showConnectionNameDidChange,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        
        sut.showConnectionName = true
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_launchAtLogin_hasGetterAndSetter() {
        let initialValue = sut.launchAtLogin
        
        sut.launchAtLogin = !initialValue
        
        XCTAssertNotEqual(sut.launchAtLogin, initialValue)
    }
    
    func test_isLaunchAtLoginAvailable_returnsBool() {
        let isAvailable = sut.isLaunchAtLoginAvailable
        
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }
}

