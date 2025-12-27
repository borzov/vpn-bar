import Foundation
import AppKit
import ServiceManagement
import os.log

/// Управляет пользовательскими настройками приложения.
@MainActor
class SettingsManager: SettingsManagerProtocol {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let updateIntervalKey = "updateInterval"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let showNotificationsKey = "showNotifications"
    private let showConnectionNameKey = "showConnectionName"
    private let launchAtLoginKey = "launchAtLogin"
    private let soundFeedbackEnabledKey = "soundFeedbackEnabled"
    private let lastUsedConnectionIDKey = "lastUsedConnectionID"
    
    private init() {}
    
    /// Интервал обновления статусов VPN в секундах.
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
    
    /// Код клавиши для глобального хоткея.
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
    
    /// Модификаторы для глобального хоткея.
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
    
    /// Сохраняет комбинацию горячей клавиши.
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
    }
    
    /// Флаг отображения системных уведомлений.
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
    
    /// Флаг показа имени подключения в тултипе.
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
    
    /// Флаг включения звуковой обратной связи.
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
    
    /// Признак автозапуска приложения при входе в систему.
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
    
    /// Проверяет доступность функции автозапуска на текущей версии macOS.
    var isLaunchAtLoginAvailable: Bool {
        if #available(macOS 13.0, *) {
            return true
        } else {
            return false
        }
    }
    
    @available(macOS, deprecated: 13.0, message: "Use SMAppService on macOS 13+")
    /// Упрощенный fallback для macOS 12, сохраняющий пожелание автозапуска.
    private func setLaunchAtLoginLegacy(enabled: Bool) {
        userDefaults.set(enabled, forKey: launchAtLoginKey)
    }
    
    /// Идентификатор последнего использованного VPN-подключения.
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
}

