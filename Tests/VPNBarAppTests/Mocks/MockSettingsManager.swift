import Foundation
@testable import VPNBarApp

@MainActor
final class MockSettingsManager: SettingsManagerProtocol {
    var updateInterval: TimeInterval = 15.0
    var hotkeyKeyCode: UInt32?
    var hotkeyModifiers: UInt32?
    var showNotifications: Bool = true
    var showConnectionName: Bool = false
    var soundFeedbackEnabled: Bool = true
    var launchAtLogin: Bool = false
    var lastUsedConnectionID: String?
    
    var isLaunchAtLoginAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    var connectionHotkeys: [ConnectionHotkey] = []

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

    func saveConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32) {
        connectionHotkeys = connectionHotkeys.filter { $0.connectionID != connectionID }
        connectionHotkeys.append(ConnectionHotkey(connectionID: connectionID, keyCode: keyCode, modifiers: modifiers))
    }

    func removeConnectionHotkey(connectionID: String) {
        connectionHotkeys = connectionHotkeys.filter { $0.connectionID != connectionID }
    }

    func connectionHotkey(for connectionID: String) -> ConnectionHotkey? {
        return connectionHotkeys.first { $0.connectionID == connectionID }
    }

    func reset() {
        updateInterval = 15.0
        hotkeyKeyCode = nil
        hotkeyModifiers = nil
        showNotifications = true
        showConnectionName = false
        launchAtLogin = false
        lastUsedConnectionID = nil
        connectionHotkeys = []
        updateIntervalChanged = false
        hotkeyChanged = false
        showConnectionNameChanged = false
        saveHotkeyCalled = false
        saveHotkeyKeyCode = nil
        saveHotkeyModifiers = nil
    }
}

