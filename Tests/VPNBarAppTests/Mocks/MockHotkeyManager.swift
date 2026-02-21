import Foundation
@testable import VPNBarApp

final class MockHotkeyManager: HotkeyManagerProtocol {
    var isRegistered = false
    var registeredKeyCode: UInt32?
    var registeredModifiers: UInt32?
    var callback: (() -> Void)?
    
    var registerHotkeyCalled = false
    var unregisterHotkeyCalled = false
    var connectionHotkeys: [String: (keyCode: UInt32, modifiers: UInt32, callback: () -> Void)] = [:]
    var registerConnectionHotkeyCalled = false
    var unregisterConnectionHotkeyCalled = false
    var unregisterAllConnectionHotkeysCalled = false

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

    func registerConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        registerConnectionHotkeyCalled = true
        connectionHotkeys[connectionID] = (keyCode: keyCode, modifiers: modifiers, callback: callback)
    }

    func unregisterConnectionHotkey(connectionID: String) {
        unregisterConnectionHotkeyCalled = true
        connectionHotkeys.removeValue(forKey: connectionID)
    }

    func unregisterAllConnectionHotkeys() {
        unregisterAllConnectionHotkeysCalled = true
        connectionHotkeys.removeAll()
    }

    func simulateHotkeyPress() {
        callback?()
    }

    func cleanup() {
        unregisterHotkey()
        unregisterAllConnectionHotkeys()
    }

    func reset() {
        isRegistered = false
        registeredKeyCode = nil
        registeredModifiers = nil
        callback = nil
        registerHotkeyCalled = false
        unregisterHotkeyCalled = false
        connectionHotkeys = [:]
        registerConnectionHotkeyCalled = false
        unregisterConnectionHotkeyCalled = false
        unregisterAllConnectionHotkeysCalled = false
    }
}

