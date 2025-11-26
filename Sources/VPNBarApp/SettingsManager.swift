import Foundation
import AppKit
import ServiceManagement
import os.log

@MainActor
class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let updateIntervalKey = "updateInterval"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let showNotificationsKey = "showNotifications"
    private let showConnectionNameKey = "showConnectionName"
    private let launchAtLoginKey = "launchAtLogin"
    
    private init() {}
    
    // MARK: - Update Interval
    
    var updateInterval: TimeInterval {
        get {
            let saved = userDefaults.double(forKey: updateIntervalKey)
            return saved > 0 ? saved : AppConstants.defaultUpdateInterval
        }
        set {
            // Валидация диапазона
            let validated = max(AppConstants.minUpdateInterval, min(AppConstants.maxUpdateInterval, newValue))
            userDefaults.set(validated, forKey: updateIntervalKey)
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
            NotificationCenter.default.post(name: .showConnectionNameDidChange, object: nil)
        }
    }
    
    // MARK: - Launch at Login
    
    var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                // Для macOS 12 читаем из UserDefaults (информационное значение)
                return userDefaults.bool(forKey: launchAtLoginKey)
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status == .enabled {
                            // Уже включено
                            return
                        }
                        try SMAppService.mainApp.register()
                    } else {
                        if SMAppService.mainApp.status != .enabled {
                            // Уже выключено
                            return
                        }
                        try SMAppService.mainApp.unregister()
                    }
                    // Сохраняем в UserDefaults для отслеживания состояния
                    userDefaults.set(newValue, forKey: launchAtLoginKey)
                } catch {
                    let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Settings")
                    logger.error("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                }
            } else {
                // Для macOS 12 используем deprecated API
                setLaunchAtLoginLegacy(enabled: newValue)
            }
        }
    }
    
    /// Проверяет, доступна ли функция Launch at Login
    var isLaunchAtLoginAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            // На macOS 12 функция ограничена
            return false
        }
    }
    
    @available(macOS, deprecated: 13.0, message: "Use SMAppService on macOS 13+")
    private func setLaunchAtLoginLegacy(enabled: Bool) {
        // На macOS 12 используем SMLoginItemSetEnabled (требует Helper app)
        // Это сложная реализация, поэтому для macOS 12 просто показываем инструкцию
        userDefaults.set(enabled, forKey: launchAtLoginKey)
    }
}

