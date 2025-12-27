import Foundation
@testable import VPNBarApp

final class MockHotkeyManager: HotkeyManagerProtocol {
    var isRegistered = false
    var registeredKeyCode: UInt32?
    var registeredModifiers: UInt32?
    var callback: (() -> Void)?
    
    var registerHotkeyCalled = false
    var unregisterHotkeyCalled = false
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        registerHotkeyCalled = true
        registeredKeyCode = keyCode
        registeredModifiers = modifiers
        self.callback = callback
        isRegistered = true
    }
    
    func unregisterHotkey() {
        unregisterHotkeyCalled = true
        registeredKeyCode = nil
        registeredModifiers = nil
        callback = nil
        isRegistered = false
    }
    
    func simulateHotkeyPress() {
        callback?()
    }
    
    func cleanup() {
        unregisterHotkey()
    }
    
    func reset() {
        isRegistered = false
        registeredKeyCode = nil
        registeredModifiers = nil
        callback = nil
        registerHotkeyCalled = false
        unregisterHotkeyCalled = false
    }
}

