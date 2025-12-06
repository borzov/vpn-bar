import Foundation
@testable import VPNBarApp

@MainActor
final class MockSettingsManager: SettingsManagerProtocol {
    var updateInterval: TimeInterval = 15.0
    var hotkeyKeyCode: UInt32?
    var hotkeyModifiers: UInt32?
    var showNotifications: Bool = true
    var showConnectionName: Bool = false
    var launchAtLogin: Bool = false
    
    var isLaunchAtLoginAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    var updateIntervalChanged = false
    var hotkeyChanged = false
    var showConnectionNameChanged = false
    var saveHotkeyCalled = false
    var saveHotkeyKeyCode: UInt32?
    var saveHotkeyModifiers: UInt32?
    
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?) {
        saveHotkeyCalled = true
        saveHotkeyKeyCode = keyCode
        saveHotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
    }
    
    func reset() {
        updateInterval = 15.0
        hotkeyKeyCode = nil
        hotkeyModifiers = nil
        showNotifications = true
        showConnectionName = false
        launchAtLogin = false
        updateIntervalChanged = false
        hotkeyChanged = false
        showConnectionNameChanged = false
        saveHotkeyCalled = false
        saveHotkeyKeyCode = nil
        saveHotkeyModifiers = nil
    }
}

