import Foundation
import AppKit
import ServiceManagement
import os.log

/// Manages application user settings.
@MainActor
class SettingsManager: SettingsManagerProtocol {
    static let shared = SettingsManager()

    private let userDefaults: UserDefaults
    private let updateIntervalKey = "updateInterval"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let showNotificationsKey = "showNotifications"
    private let showConnectionNameKey = "showConnectionName"
    private let launchAtLoginKey = "launchAtLogin"
    private let soundFeedbackEnabledKey = "soundFeedbackEnabled"
    private let lastUsedConnectionIDKey = "lastUsedConnectionID"
    private let connectionHotkeysKey = "connectionHotkeys"

    private var cachedConnectionHotkeys: [ConnectionHotkey]?

    private init() {
        self.userDefaults = UserDefaults.standard
    }

    /// Designated initializer for tests with custom UserDefaults.
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
    
    /// VPN status update interval in seconds.
    var updateInterval: TimeInterval {
        get {
            let saved = userDefaults.double(forKey: updateIntervalKey)
            return saved > 0 ? saved : AppConstants.defaultUpdateInterval
        }
        set {
            let validated = newValue.clamped(to: AppConstants.minUpdateInterval...AppConstants.maxUpdateInterval)
            userDefaults.set(validated, forKey: updateIntervalKey)
            NotificationCenter.default.post(name: .updateIntervalDidChange, object: nil)
        }
    }
    
    /// Global hotkey key code.
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
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    /// Global hotkey modifiers.
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
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    /// Saves hotkey combination.
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
    }
    
    /// Flag for showing system notifications.
    var showNotifications: Bool {
        get {
            if userDefaults.object(forKey: showNotificationsKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: showNotificationsKey)
        }
        set {
            userDefaults.set(newValue, forKey: showNotificationsKey)
        }
    }
    
    /// Flag for showing connection name in tooltip.
    var showConnectionName: Bool {
        get {
            if userDefaults.object(forKey: showConnectionNameKey) == nil {
                return false
            }
            return userDefaults.bool(forKey: showConnectionNameKey)
        }
        set {
            userDefaults.set(newValue, forKey: showConnectionNameKey)
            NotificationCenter.default.post(name: .showConnectionNameDidChange, object: nil)
        }
    }
    
    /// Flag for enabling sound feedback.
    var soundFeedbackEnabled: Bool {
        get {
            if userDefaults.object(forKey: soundFeedbackEnabledKey) == nil {
                return true
            }
            return userDefaults.bool(forKey: soundFeedbackEnabledKey)
        }
        set {
            userDefaults.set(newValue, forKey: soundFeedbackEnabledKey)
        }
    }
    
    /// Flag for launching application at login.
    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return userDefaults.bool(forKey: launchAtLoginKey)
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status == .enabled {
                            return
                        }
                        try SMAppService.mainApp.register()
                    } else {
                        if SMAppService.mainApp.status != .enabled {
                            return
                        }
                        try SMAppService.mainApp.unregister()
                    }
                    userDefaults.set(newValue, forKey: launchAtLoginKey)
                } catch {
                    let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Settings")
                    logger.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                }
            } else {
                setLaunchAtLoginLegacy(enabled: newValue)
            }
        }
    }
    
    /// Checks if launch at login is available on current macOS version.
    var isLaunchAtLoginAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    @available(macOS, deprecated: 13.0, message: "Use SMAppService on macOS 13+")
    /// Simplified fallback for macOS 12, saves launch at login preference.
    private func setLaunchAtLoginLegacy(enabled: Bool) {
        userDefaults.set(enabled, forKey: launchAtLoginKey)
    }
    
    /// Identifier of the last used VPN connection.
    var lastUsedConnectionID: String? {
        get {
            return userDefaults.string(forKey: lastUsedConnectionIDKey)
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: lastUsedConnectionIDKey)
            } else {
                userDefaults.removeObject(forKey: lastUsedConnectionIDKey)
            }
        }
    }

    /// Per-connection hotkey assignments.
    var connectionHotkeys: [ConnectionHotkey] {
        get {
            if let cached = cachedConnectionHotkeys {
                return cached
            }
            guard let data = userDefaults.data(forKey: connectionHotkeysKey),
                  let hotkeys = try? JSONDecoder().decode([ConnectionHotkey].self, from: data) else {
                cachedConnectionHotkeys = []
                return []
            }
            cachedConnectionHotkeys = hotkeys
            return hotkeys
        }
        set {
            cachedConnectionHotkeys = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: connectionHotkeysKey)
            }
            NotificationCenter.default.post(name: .connectionHotkeysDidChange, object: nil)
        }
    }

    func saveConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32) {
        var hotkeys = connectionHotkeys.filter { $0.connectionID != connectionID }
        hotkeys.append(ConnectionHotkey(connectionID: connectionID, keyCode: keyCode, modifiers: modifiers))
        connectionHotkeys = hotkeys
    }

    func removeConnectionHotkey(connectionID: String) {
        connectionHotkeys = connectionHotkeys.filter { $0.connectionID != connectionID }
    }

    func connectionHotkey(for connectionID: String) -> ConnectionHotkey? {
        return connectionHotkeys.first { $0.connectionID == connectionID }
    }
}

