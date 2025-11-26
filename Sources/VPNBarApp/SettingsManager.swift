import Foundation
import AppKit

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let updateIntervalKey = "updateInterval"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let showNotificationsKey = "showNotifications"
    private let showConnectionNameKey = "showConnectionName"
    
    private init() {}
    
    // MARK: - Update Interval
    
    var updateInterval: TimeInterval {
        get {
            let saved = userDefaults.double(forKey: updateIntervalKey)
            return saved > 0 ? saved : 10.0 // Значение по умолчанию
        }
        set {
            userDefaults.set(newValue, forKey: updateIntervalKey)
            userDefaults.synchronize()
            NotificationCenter.default.post(name: .updateIntervalDidChange, object: nil)
        }
    }
    
    // MARK: - Hotkey
    
    var hotkeyKeyCode: UInt32? {
        get {
            let value = userDefaults.integer(forKey: hotkeyKeyCodeKey)
            return value > 0 ? UInt32(value) : nil
        }
        set {
            if let value = newValue {
                userDefaults.set(Int(value), forKey: hotkeyKeyCodeKey)
            } else {
                userDefaults.removeObject(forKey: hotkeyKeyCodeKey)
            }
            userDefaults.synchronize()
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    var hotkeyModifiers: UInt32? {
        get {
            let value = userDefaults.integer(forKey: hotkeyModifiersKey)
            return value > 0 ? UInt32(value) : nil
        }
        set {
            if let value = newValue {
                userDefaults.set(Int(value), forKey: hotkeyModifiersKey)
            } else {
                userDefaults.removeObject(forKey: hotkeyModifiersKey)
            }
            userDefaults.synchronize()
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
    }
    
    // MARK: - Notifications
    
    var showNotifications: Bool {
        get {
            if userDefaults.object(forKey: showNotificationsKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: showNotificationsKey)
        }
        set {
            userDefaults.set(newValue, forKey: showNotificationsKey)
            userDefaults.synchronize()
        }
    }
    
    // MARK: - Display
    
    var showConnectionName: Bool {
        get {
            if userDefaults.object(forKey: showConnectionNameKey) == nil {
                return false
            }
            return userDefaults.bool(forKey: showConnectionNameKey)
        }
        set {
            userDefaults.set(newValue, forKey: showConnectionNameKey)
            userDefaults.synchronize()
            NotificationCenter.default.post(name: .showConnectionNameDidChange, object: nil)
        }
    }
}

