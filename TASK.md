# Техническое задание на версию 0.3.0

## Обзор

Подготовить версию 0.3.0 приложения VPNBarApp с улучшениями стабильности, UX и архитектуры.

---

## Часть 1: Критические исправления

### 1.1. Замена NSUserNotification на UserNotifications Framework

**Проблема:** `NSUserNotification` deprecated и не работает на macOS 11+.

**Особенности реализации для menu bar приложений:**

> ⚠️ **ВАЖНО:** Для LSUIElement приложений (без иконки в Dock) есть особенности:
> 1. Необходимо добавить `NSUserNotificationCenter` delegate для обработки уведомлений
> 2. Для menu bar apps рекомендуется использовать `UNUserNotificationCenter` с provisional authorization
> 3. Приложение должно быть подписано (даже ad-hoc) для работы уведомлений

**Файлы для изменения:**
- `Sources/VPNBarApp/AppDelegate.swift`
- `Sources/VPNBarApp/StatusBarController.swift`
- Создать новый файл: `Sources/VPNBarApp/NotificationManager.swift`

**Реализация NotificationManager.swift:**

```swift
import Foundation
import UserNotifications
import os.log

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Notifications")
    @Published private(set) var isAuthorized = false
    
    private override init() {
        super.init()
    }
    
    /// Запрашивает разрешение на уведомления
    /// Для menu bar приложений использует provisional authorization
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // Для menu bar apps лучше использовать provisional - не показывает диалог,
        // но уведомления будут доставляться в Notification Center тихо
        let options: UNAuthorizationOptions = [.alert, .sound, .provisional]
        
        center.requestAuthorization(options: options) { [weak self] granted, error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("Notification authorization error: \(error.localizedDescription)")
                }
                self?.isAuthorized = granted
                self?.logger.info("Notification authorization: \(granted)")
            }
        }
    }
    
    /// Проверяет текущий статус авторизации
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                let authorized = settings.authorizationStatus == .authorized || 
                                settings.authorizationStatus == .provisional
                self?.isAuthorized = authorized
            }
        }
    }
    
    /// Отправляет уведомление о подключении/отключении VPN
    func sendVPNNotification(isConnected: Bool, connectionName: String?) {
        guard isAuthorized else {
            logger.warning("Notifications not authorized, skipping")
            return
        }
        
        let content = UNMutableNotificationContent()
        
        if isConnected {
            content.title = NSLocalizedString("VPN Connected", comment: "")
            if let name = connectionName {
                content.body = String(format: NSLocalizedString("Connected to %@", comment: ""), name)
            }
        } else {
            content.title = NSLocalizedString("VPN Disconnected", comment: "")
            if let name = connectionName {
                content.body = String(format: NSLocalizedString("Disconnected from %@", comment: ""), name)
            }
        }
        
        // Используем default звук
        content.sound = .default
        
        // Категория для возможных действий в будущем
        content.categoryIdentifier = "VPN_STATUS"
        
        // Уникальный идентификатор, чтобы новое уведомление заменяло старое
        let identifier = "vpn-status-\(connectionName ?? "default")"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Немедленная доставка
        )
        
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                self?.logger.info("Notification delivered: \(content.title)")
            }
        }
    }
    
    /// Удаляет все доставленные уведомления приложения
    func removeAllDeliveredNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// Позволяет показывать уведомления даже когда приложение активно
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Показываем banner и воспроизводим звук даже если приложение активно
        completionHandler([.banner, .sound])
    }
    
    /// Обрабатывает нажатие на уведомление
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Можно добавить обработку действий в будущем
        completionHandler()
    }
}
```

**Изменения в AppDelegate.swift:**

```swift
import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AppDelegate")
        logger.info("Application did finish launching")
        
        // Запрашиваем разрешение на уведомления
        Task { @MainActor in
            NotificationManager.shared.requestAuthorization()
        }
        
        // Создаем контроллер меню-бара
        statusBarController = StatusBarController()
        
        // ... остальной код без изменений
    }
    
    // ... остальные методы
}
```

**Изменения в StatusBarController.swift:**

Заменить метод `sendNotification` на использование `NotificationManager`:

```swift
// Удалить старый метод sendNotification и заменить вызов на:
private func notifyStatusChange(isNowActive: Bool, connectionName: String?) {
    guard SettingsManager.shared.showNotifications else { return }
    
    Task { @MainActor in
        NotificationManager.shared.sendVPNNotification(
            isConnected: isNowActive,
            connectionName: connectionName
        )
    }
}
```

**Добавить в Info.plist (в package_app.sh):**

```xml
<key>NSUserNotificationAlertStyle</key>
<string>banner</string>
```

---

### 1.2. Исправление утечки памяти в HotkeyManager

**Файл:** `Sources/VPNBarApp/HotkeyManager.swift`

**Изменения:**

```swift
import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNT"), id: 1)
    private var isRegistered = false
    private var callback: (() -> Void)?
    private var eventHandler: EventHandlerRef?
    
    // Добавляем флаг для отслеживания состояния
    private var isSetup = false
    
    private init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        guard !isSetup else { return }
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        // Сохраняем ссылку на self в статическую переменную для безопасного доступа
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        let eventHandlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { 
                return OSStatus(eventNotHandledErr) 
            }
            
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if err == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                // Проверяем что это наш hotkey
                if hotKeyID.id == manager.hotKeyID.id && 
                   hotKeyID.signature == manager.hotKeyID.signature {
                    // Безопасно вызываем callback на main thread
                    if let callback = manager.callback {
                        DispatchQueue.main.async {
                            callback()
                        }
                    }
                    return noErr
                }
            }
            
            return OSStatus(eventNotHandledErr)
        }
        
        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerUPP,
            1,
            &eventSpec,
            userData,
            &handlerRef
        )
        
        if status == noErr {
            self.eventHandler = handlerRef
            self.isSetup = true
        }
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        // Сначала отменяем предыдущую регистрацию
        unregisterHotkey()
        
        self.callback = callback
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            self.hotKeyRef = ref
            self.isRegistered = true
        } else {
            self.callback = nil
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef, isRegistered {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isRegistered = false
        }
        callback = nil
    }
    
    deinit {
        unregisterHotkey()
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        isSetup = false
    }
}

// ... extension FourCharCode без изменений
```

---

### 1.3. Устранение Force Unwrap

**Файл:** `Sources/VPNBarApp/SettingsWindowController.swift`

**Найти и заменить все `hotkeyButton!` на безопасные варианты:**

```swift
// Было:
stopRecordingHotkey()
updateHotkeyButtonTitle(hotkeyButton!)

// Стало:
stopRecordingHotkey()
if let button = hotkeyButton {
    updateHotkeyButtonTitle(button)
}

// Или использовать guard:
private func stopRecordingHotkey() {
    isRecordingHotkey = false
    
    if let button = hotkeyButton {
        updateHotkeyButtonTitle(button)
    }
    
    // Удаляем мониторы событий
    if let monitor = globalEventMonitor {
        NSEvent.removeMonitor(monitor)
        globalEventMonitor = nil
    }
    if let monitor = localEventMonitor {
        NSEvent.removeMonitor(monitor)
        localEventMonitor = nil
    }
}
```

**Полный список мест для исправления в SettingsWindowController.swift:**

1. Строка с `updateHotkeyButtonTitle(hotkeyButton!)` в `stopRecordingHotkey()`
2. Строка с `updateHotkeyButtonTitle(hotkeyButton!)` в `handleHotkeyEvent()` (после Escape)
3. Строка с `updateHotkeyButtonTitle(hotkeyButton!)` в `clearHotkey()`
4. Строка с `updateHotkeyButtonTitle(hotkeyButton!)` в `saveHotkey()`

---

### 1.4. Обработка ошибок доступа к VPN

**Файл:** `Sources/VPNBarApp/VPNManager.swift`

**Добавить published property для ошибки:**

```swift
class VPNManager: ObservableObject {
    static let shared = VPNManager()
    
    @Published var connections: [VPNConnection] = []
    @Published var hasActiveConnection: Bool = false
    @Published var loadingError: String?  // НОВОЕ
    
    // ... остальной код
    
    func loadConnections(forceReload: Bool = false) {
        // В начале метода:
        loadingError = nil
        
        // ... существующий код загрузки ...
        
        // После получения connections, в конце handler'а:
        DispatchQueue.main.async {
            // ... существующий код ...
            
            self.connections = connections.sorted { $0.name < $1.name }
            
            // НОВОЕ: Устанавливаем сообщение об ошибке если нет подключений
            if self.connections.isEmpty {
                self.loadingError = NSLocalizedString(
                    "No VPN configurations found. Configure VPN in System Preferences → Network.",
                    comment: ""
                )
            }
            
            self.updateActiveStatus()
        }
    }
}
```

**Файл:** `Sources/VPNBarApp/MenuController.swift`

**Показывать ошибку в меню:**

```swift
private func buildMenu() {
    let newMenu = NSMenu()
    newMenu.appearance = NSApp.effectiveAppearance
    
    // Показываем ошибку если есть
    if let error = vpnManager.loadingError {
        let errorItem = NSMenuItem(title: error, action: nil, keyEquivalent: "")
        errorItem.isEnabled = false
        // Добавляем иконку предупреждения
        if let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
            image.isTemplate = true
            errorItem.image = image
        }
        newMenu.addItem(errorItem)
        
        // Добавляем кнопку открытия настроек сети
        let openNetworkPrefsItem = NSMenuItem(
            title: NSLocalizedString("Open Network Preferences...", comment: ""),
            action: #selector(openNetworkPreferences(_:)),
            keyEquivalent: ""
        )
        openNetworkPrefsItem.target = self
        newMenu.addItem(openNetworkPrefsItem)
    } else if vpnManager.connections.isEmpty {
        // ... существующий код для пустого списка
    } else {
        // ... существующий код для списка подключений
    }
    
    // ... остальной код
}

@objc private func openNetworkPreferences(_ sender: NSMenuItem) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
        NSWorkspace.shared.open(url)
    }
}
```

**Добавить локализацию:**

```
// en.lproj/Localizable.strings
"No VPN configurations found. Configure VPN in System Preferences → Network." = "No VPN configurations found. Configure VPN in System Preferences → Network.";
"Open Network Preferences..." = "Open Network Preferences...";

// ru.lproj/Localizable.strings  
"No VPN configurations found. Configure VPN in System Preferences → Network." = "VPN-подключения не найдены. Настройте VPN в Системных настройках → Сеть.";
"Open Network Preferences..." = "Открыть настройки сети...";
```

---

### 1.5. Удаление устаревших вызовов synchronize()

**Файл:** `Sources/VPNBarApp/SettingsManager.swift`

**Удалить все строки с `userDefaults.synchronize()`**

```swift
// Удалить эти строки везде где встречается:
userDefaults.synchronize()
```

Всего примерно 6 мест в файле. Просто удалить эти строки.

---

### 1.6. Вынести Bundle ID и другие константы

**Создать новый файл:** `Sources/VPNBarApp/AppConstants.swift`

```swift
import Foundation

enum AppConstants {
    /// Bundle identifier приложения
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.borzov.VPNBar"
    
    /// Название приложения для отображения
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "VPN Bar"
    
    /// Версия приложения
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    
    /// Номер сборки
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    
    /// Минимальный интервал обновления статуса (секунды)
    static let minUpdateInterval: TimeInterval = 5.0
    
    /// Максимальный интервал обновления статуса (секунды)
    static let maxUpdateInterval: TimeInterval = 120.0
    
    /// Интервал обновления статуса по умолчанию (секунды)
    static let defaultUpdateInterval: TimeInterval = 15.0
    
    /// Интервал обновления статуса сессий (секунды)
    static let sessionStatusUpdateInterval: TimeInterval = 5.0
}
```

**Обновить все файлы, где используется hardcoded bundle ID:**

```swift
// Заменить везде:
Logger(subsystem: "com.borzov.VPNBar", category: "...")

// На:
Logger(subsystem: AppConstants.bundleIdentifier, category: "...")
```

**Файлы для обновления:**
- `AppDelegate.swift`
- `StatusBarController.swift`
- `VPNManager.swift`
- Любые другие места с hardcoded строками

---

### 1.7. Валидация горячих клавиш

**Файл:** `Sources/VPNBarApp/SettingsWindowController.swift`

**Добавить методы валидации:**

```swift
// MARK: - Hotkey Validation

/// Проверяет, является ли комбинация системной/зарезервированной
private func isSystemReservedHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
    // Системные комбинации macOS, которые нельзя переопределять
    let reservedHotkeys: [(keyCode: UInt32, modifiers: UInt32)] = [
        // Cmd+Q - Quit
        (12, UInt32(cmdKey)),
        // Cmd+W - Close Window
        (13, UInt32(cmdKey)),
        // Cmd+Tab - App Switcher
        (48, UInt32(cmdKey)),
        // Cmd+Space - Spotlight
        (49, UInt32(cmdKey)),
        // Cmd+H - Hide
        (4, UInt32(cmdKey)),
        // Cmd+M - Minimize
        (46, UInt32(cmdKey)),
        // Cmd+, - Preferences (мы используем это для настроек)
        (43, UInt32(cmdKey)),
        // Ctrl+Cmd+Q - Lock Screen
        (12, UInt32(cmdKey) | UInt32(controlKey)),
        // Cmd+Shift+Q - Log Out
        (12, UInt32(cmdKey) | UInt32(shiftKey)),
    ]
    
    return reservedHotkeys.contains { $0.keyCode == keyCode && $0.modifiers == modifiers }
}

/// Проверяет, содержит ли комбинация хотя бы один модификатор
private func hasRequiredModifiers(_ modifiers: UInt32) -> Bool {
    // Должен быть хотя бы Cmd, Ctrl или Option (Shift один - не считается)
    let hasCmd = modifiers & UInt32(cmdKey) != 0
    let hasCtrl = modifiers & UInt32(controlKey) != 0
    let hasOption = modifiers & UInt32(optionKey) != 0
    
    return hasCmd || hasCtrl || hasOption
}

/// Показывает предупреждение о некорректной горячей клавише
private func showHotkeyValidationError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Invalid Hotkey", comment: "")
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
    alert.runModal()
}
```

**Обновить метод handleHotkeyEvent:**

```swift
private func handleHotkeyEvent(_ event: NSEvent) {
    guard isRecordingHotkey else { return }
    
    if event.type == .keyDown {
        let keyCode = UInt32(event.keyCode)
        
        // Escape отменяет запись
        if keyCode == 53 { // Escape key
            stopRecordingHotkey()
            if let button = hotkeyButton {
                updateHotkeyButtonTitle(button)
            }
            return
        }
        
        // Преобразуем NSEvent модификаторы в Carbon модификаторы
        var carbonModifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }
        if event.modifierFlags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        
        // НОВОЕ: Проверка на наличие модификаторов
        if !hasRequiredModifiers(carbonModifiers) {
            showHotkeyValidationError(
                NSLocalizedString(
                    "Hotkey must include at least one modifier key (⌘, ⌃, or ⌥).",
                    comment: ""
                )
            )
            return
        }
        
        // НОВОЕ: Проверка на системные комбинации
        if isSystemReservedHotkey(keyCode: keyCode, modifiers: carbonModifiers) {
            showHotkeyValidationError(
                NSLocalizedString(
                    "This key combination is reserved by the system. Please choose another.",
                    comment: ""
                )
            )
            return
        }
        
        recordedKeyCode = keyCode
        recordedModifiers = carbonModifiers
        
        // Сохраняем и останавливаем запись
        stopRecordingHotkey()
        saveHotkey()
    }
}
```

**Добавить локализацию:**

```
// en.lproj/Localizable.strings
"Invalid Hotkey" = "Invalid Hotkey";
"Hotkey must include at least one modifier key (⌘, ⌃, or ⌥)." = "Hotkey must include at least one modifier key (⌘, ⌃, or ⌥).";
"This key combination is reserved by the system. Please choose another." = "This key combination is reserved by the system. Please choose another.";

// ru.lproj/Localizable.strings
"Invalid Hotkey" = "Некорректная комбинация";
"Hotkey must include at least one modifier key (⌘, ⌃, or ⌥)." = "Комбинация должна содержать хотя бы одну клавишу-модификатор (⌘, ⌃ или ⌥).";
"This key combination is reserved by the system. Please choose another." = "Эта комбинация клавиш зарезервирована системой. Выберите другую.";
```

---

### 1.8. Launch at Login

**ВАЖНО:** Для macOS 13+ использовать `SMAppService`. Для поддержки macOS 12 нужен fallback.

**Файл:** `Sources/VPNBarApp/SettingsManager.swift`

**Добавить property и методы:**

```swift
import ServiceManagement

class SettingsManager {
    // ... существующий код ...
    
    private let launchAtLoginKey = "launchAtLogin"
    
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
```

**Файл:** `Sources/VPNBarApp/SettingsWindowController.swift`

**Добавить UI для Launch at Login в createGeneralView():**

```swift
private func createGeneralView() -> NSView {
    let contentView = NSView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    
    let mainStack = NSStackView()
    mainStack.orientation = .vertical
    mainStack.alignment = .leading
    mainStack.distribution = .fill
    mainStack.spacing = 20
    mainStack.translatesAutoresizingMaskIntoConstraints = false
    
    // НОВОЕ: Секция: Запуск
    let startupSection = createStartupSection()
    mainStack.addArrangedSubview(startupSection)
    
    // Секция: Интервал обновления
    let intervalSection = createIntervalSection()
    mainStack.addArrangedSubview(intervalSection)
    
    // ... остальной код без изменений
}

// НОВОЕ: Добавить метод создания секции
private var launchAtLoginCheckbox: NSButton?

private func createStartupSection() -> NSView {
    let sectionStack = NSStackView()
    sectionStack.orientation = .vertical
    sectionStack.alignment = .leading
    sectionStack.distribution = .fill
    sectionStack.spacing = 6
    
    // Заголовок секции
    let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Startup", comment: ""))
    sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    sectionStack.addArrangedSubview(sectionLabel)
    
    // Чекбокс
    let checkbox = NSButton(
        checkboxWithTitle: NSLocalizedString("Launch at login", comment: ""),
        target: self,
        action: #selector(launchAtLoginChanged(_:))
    )
    checkbox.state = settingsManager.launchAtLogin ? .on : .off
    checkbox.font = NSFont.systemFont(ofSize: 13)
    
    // Отключаем чекбокс если функция недоступна (macOS < 13)
    if !settingsManager.isLaunchAtLoginAvailable {
        checkbox.isEnabled = false
    }
    
    self.launchAtLoginCheckbox = checkbox
    sectionStack.addArrangedSubview(checkbox)
    
    // Описание
    var descriptionText = NSLocalizedString("Automatically start VPN Bar when you log in.", comment: "")
    if !settingsManager.isLaunchAtLoginAvailable {
        descriptionText += " " + NSLocalizedString("(Requires macOS 13 or later)", comment: "")
    }
    
    let description = NSTextField(wrappingLabelWithString: descriptionText)
    description.font = NSFont.systemFont(ofSize: 11)
    description.textColor = .secondaryLabelColor
    description.preferredMaxLayoutWidth = 524
    sectionStack.addArrangedSubview(description)
    
    return sectionStack
}

@objc private func launchAtLoginChanged(_ sender: NSButton) {
    settingsManager.launchAtLogin = sender.state == .on
}

// В методе showWindow() добавить обновление чекбокса:
func showWindow() {
    // ... существующий код ...
    launchAtLoginCheckbox?.state = settingsManager.launchAtLogin ? .on : .off
    // ... остальной код ...
}
```

**Добавить локализацию:**

```
// en.lproj/Localizable.strings
"Startup" = "Startup";
"Launch at login" = "Launch at login";
"Automatically start VPN Bar when you log in." = "Automatically start VPN Bar when you log in.";
"(Requires macOS 13 or later)" = "(Requires macOS 13 or later)";

// ru.lproj/Localizable.strings
"Startup" = "Запуск";
"Launch at login" = "Запускать при входе в систему";
"Automatically start VPN Bar when you log in." = "Автоматически запускать VPN Bar при входе в систему.";
"(Requires macOS 13 or later)" = "(Требуется macOS 13 или новее)";
```

---

### 1.9. Оптимизация интервала обновления

**Файл:** `Sources/VPNBarApp/VPNManager.swift`

**Изменить стратегию обновления:**

```swift
class VPNManager: ObservableObject {
    // ... существующие properties ...
    
    // ИЗМЕНЕНО: Увеличен интервал обновления статусов
    private let statusUpdateInterval: TimeInterval = AppConstants.sessionStatusUpdateInterval
    
    // НОВОЕ: Флаг для отслеживания активности event handlers
    private var hasActiveEventHandlers = false
    
    // ... существующий код ...
    
    private func startMonitoring() {
        stopMonitoring()
        
        // Обновляем список подключений с настраиваемым интервалом
        // Увеличиваем минимальный интервал до 15 секунд
        let effectiveInterval = max(AppConstants.minUpdateInterval, updateInterval)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadConnections(forceReload: false)
            }
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
        
        // Таймер для обновления статусов - только как резервный механизм
        // Event handlers в ne_session_set_event_handler должны обрабатывать большинство изменений
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshAllStatuses()
            }
        }
        RunLoop.current.add(statusUpdateTimer!, forMode: .common)
    }
    
    // ... остальной код без изменений
}
```

**Файл:** `Sources/VPNBarApp/SettingsManager.swift`

**Обновить значения по умолчанию:**

```swift
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
```

---

## Часть 2: Улучшения UX

### 2.1. Анимация при подключении

**Файл:** `Sources/VPNBarApp/StatusBarController.swift`

**Добавить анимацию:**

```swift
class StatusBarController {
    // ... существующие properties ...
    
    // НОВОЕ: Таймер анимации
    private var connectingAnimationTimer: Timer?
    private var animationFrame = 0
    
    // ... существующий код ...
    
    private func updateIcon(isActive: Bool) {
        guard let button = statusItem?.button else { return }
        
        // Останавливаем анимацию если она была
        stopConnectingAnimation()
        
        // Проверяем, есть ли подключения в процессе
        let isConnecting = vpnManager.connections.contains { 
            $0.status == .connecting || $0.status == .disconnecting 
        }
        
        if isConnecting {
            startConnectingAnimation()
            return
        }
        
        if isActive {
            let symbolName = "network.badge.shield.half.filled"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                image.isTemplate = true
                button.image = image
                button.contentTintColor = nil
            } else {
                button.title = "🔒"
                button.contentTintColor = nil
            }
        } else {
            let symbolName = "network"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                image.isTemplate = true
                let grayImage = createGrayedImage(from: image)
                button.image = grayImage
                button.contentTintColor = nil
            } else {
                button.title = "🔓"
                button.contentTintColor = nil
            }
        }
        
        updateTooltip()
    }
    
    // НОВОЕ: Методы анимации
    private func startConnectingAnimation() {
        guard connectingAnimationTimer == nil else { return }
        
        animationFrame = 0
        connectingAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.animateConnectingIcon()
        }
        RunLoop.current.add(connectingAnimationTimer!, forMode: .common)
        
        // Запускаем первый кадр сразу
        animateConnectingIcon()
    }
    
    private func stopConnectingAnimation() {
        connectingAnimationTimer?.invalidate()
        connectingAnimationTimer = nil
        animationFrame = 0
    }
    
    private func animateConnectingIcon() {
        guard let button = statusItem?.button else { return }
        
        // Чередуем иконки для создания эффекта анимации
        let symbols = [
            "network",
            "network.badge.shield.half.filled"
        ]
        
        let symbolName = symbols[animationFrame % symbols.count]
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            // Добавляем небольшую прозрачность для индикации процесса
            let animatedImage = NSImage(size: image.size)
            animatedImage.lockFocus()
            image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 0.7)
            animatedImage.unlockFocus()
            animatedImage.isTemplate = true
            button.image = animatedImage
        }
        
        animationFrame += 1
    }
    
    // Обновить observeVPNStatus для отслеживания изменений статуса подключений
    private func observeVPNStatus() {
        vpnManager.$hasActiveConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.updateIcon(isActive: isActive)
            }
            .store(in: &cancellables)
        
        vpnManager.$connections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connections in
                guard let self = self else { return }
                // Проверяем наличие connecting/disconnecting состояний
                let hasTransitionalState = connections.contains {
                    $0.status == .connecting || $0.status == .disconnecting
                }
                if hasTransitionalState {
                    self.startConnectingAnimation()
                } else {
                    self.stopConnectingAnimation()
                    self.updateIcon(isActive: self.vpnManager.hasActiveConnection)
                }
                self.updateTooltip()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stopConnectingAnimation()
        // ... другой cleanup если есть
    }
}
```

---

### 2.2. Accessibility

**Файл:** `Sources/VPNBarApp/StatusBarController.swift`

**Добавить accessibility в setupStatusBar():**

```swift
private func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    guard let statusItem = statusItem else { return }
    
    // Устанавливаем начальную иконку
    updateIcon(isActive: vpnManager.hasActiveConnection)
    
    // Обработчик клика
    if let button = statusItem.button {
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // НОВОЕ: Accessibility
        button.setAccessibilityLabel(NSLocalizedString("VPN Status", comment: "Accessibility label for status bar button"))
        button.setAccessibilityHelp(NSLocalizedString("Click to toggle VPN, right-click for menu", comment: "Accessibility help"))
        button.setAccessibilityRole(.button)
    }
}

// Обновить updateTooltip для accessibility:
private func updateTooltip() {
    guard let button = statusItem?.button else { return }
    
    let isActive = vpnManager.hasActiveConnection
    let settings = SettingsManager.shared
    
    var tooltipText: String
    var accessibilityValue: String
    
    if isActive {
        if settings.showConnectionName,
           let activeConnection = vpnManager.connections.first(where: { $0.status.isActive }) {
            tooltipText = activeConnection.name
            accessibilityValue = String(format: NSLocalizedString("Connected to %@", comment: ""), activeConnection.name)
        } else {
            tooltipText = NSLocalizedString("VPN Connected", comment: "")
            accessibilityValue = tooltipText
        }
    } else {
        tooltipText = NSLocalizedString("VPN Disconnected", comment: "")
        accessibilityValue = tooltipText
    }
    
    button.toolTip = tooltipText
    
    // НОВОЕ: Accessibility value
    button.setAccessibilityValue(accessibilityValue)
}
```

**Файл:** `Sources/VPNBarApp/MenuController.swift`

**Добавить accessibility для пунктов меню:**

```swift
private func buildMenu() {
    // ... существующий код создания меню ...
    
    for connection in vpnManager.connections {
        let menuItem = NSMenuItem(
            title: connection.name,
            action: #selector(vpnConnectionToggled(_:)),
            keyEquivalent: ""
        )
        // ... существующий код ...
        
        // НОВОЕ: Accessibility
        let statusDescription: String
        switch connection.status {
        case .connected:
            statusDescription = NSLocalizedString("Connected", comment: "")
        case .connecting:
            statusDescription = NSLocalizedString("Connecting", comment: "")
        case .disconnecting:
            statusDescription = NSLocalizedString("Disconnecting", comment: "")
        case .disconnected:
            statusDescription = NSLocalizedString("Disconnected", comment: "")
        }
        
        menuItem.setAccessibilityLabel("\(connection.name), \(statusDescription)")
        menuItem.setAccessibilityHelp(NSLocalizedString("Click to toggle connection", comment: ""))
        
        newMenu.addItem(menuItem)
    }
    
    // ... остальной код
}
```

**Добавить локализацию:**

```
// en.lproj/Localizable.strings
"VPN Status" = "VPN Status";
"Click to toggle VPN, right-click for menu" = "Click to toggle VPN, right-click for menu";
"Click to toggle connection" = "Click to toggle connection";

// ru.lproj/Localizable.strings
"VPN Status" = "Статус VPN";
"Click to toggle VPN, right-click for menu" = "Нажмите для переключения VPN, правый клик для меню";
"Click to toggle connection" = "Нажмите для переключения подключения";
```

---

### 2.3. Disconnect All

**Файл:** `Sources/VPNBarApp/VPNManager.swift`

**Добавить метод:**

```swift
/// Отключает все активные VPN-подключения
func disconnectAll() {
    let activeConnections = connections.filter { $0.status.isActive }
    
    for connection in activeConnections {
        disconnect(from: connection.id)
    }
}
```

**Файл:** `Sources/VPNBarApp/MenuController.swift`

**Добавить пункт меню:**

```swift
private func buildMenu() {
    let newMenu = NSMenu()
    newMenu.appearance = NSApp.effectiveAppearance
    
    // ... код отображения ошибки и списка подключений ...
    
    // НОВОЕ: Добавляем "Disconnect All" если есть активные подключения
    let hasActiveConnections = vpnManager.connections.contains { $0.status.isActive }
    if hasActiveConnections && vpnManager.connections.count > 1 {
        newMenu.addItem(NSMenuItem.separator())
        
        let disconnectAllItem = NSMenuItem(
            title: NSLocalizedString("Disconnect All", comment: ""),
            action: #selector(disconnectAllConnections(_:)),
            keyEquivalent: ""
        )
        disconnectAllItem.target = self
        if let image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) {
            image.isTemplate = true
            disconnectAllItem.image = image
        }
        newMenu.addItem(disconnectAllItem)
    }
    
    newMenu.addItem(NSMenuItem.separator())
    
    // ... остальной код (Settings, Quit)
}

@objc private func disconnectAllConnections(_ sender: NSMenuItem) {
    vpnManager.disconnectAll()
    
    // Обновляем меню через небольшую задержку
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.updateMenu()
    }
}
```

**Добавить локализацию:**

```
// en.lproj/Localizable.strings
"Disconnect All" = "Disconnect All";

// ru.lproj/Localizable.strings
"Disconnect All" = "Отключить все";
```

---

## Часть 3: Архитектурные улучшения

### 3.1. Notification.Name extensions

**Создать файл:** `Sources/VPNBarApp/Extensions/Notification+Extensions.swift`

```swift
import Foundation

extension Notification.Name {
    // Settings changes
    static let hotkeyDidChange = Notification.Name("HotkeyDidChange")
    static let updateIntervalDidChange = Notification.Name("UpdateIntervalDidChange")
    static let showConnectionNameDidChange = Notification.Name("ShowConnectionNameDidChange")
    static let showNotificationsDidChange = Notification.Name("ShowNotificationsDidChange")
    
    // VPN status changes
    static let vpnStatusDidChange = Notification.Name("VPNStatusDidChange")
    static let vpnConnectionsDidLoad = Notification.Name("VPNConnectionsDidLoad")
}
```

**Обновить все файлы, заменив строковые литералы на константы:**

```swift
// Было:
NotificationCenter.default.post(name: NSNotification.Name("HotkeyDidChange"), object: nil)

// Стало:
NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)

// Было:
NotificationCenter.default.addObserver(
    self,
    selector: #selector(hotkeyDidChange),
    name: NSNotification.Name("HotkeyDidChange"),
    object: nil
)

// Стало:
NotificationCenter.default.addObserver(
    self,
    selector: #selector(hotkeyDidChange),
    name: .hotkeyDidChange,
    object: nil
)
```

**Файлы для обновления:**
- `SettingsManager.swift`
- `SettingsWindowController.swift`
- `AppDelegate.swift`
- `StatusBarController.swift`

---

### 3.2. @MainActor для thread safety

**Файл:** `Sources/VPNBarApp/VPNManager.swift`

```swift
@MainActor
class VPNManager: ObservableObject {
    // ... весь код класса ...
    
    // Методы, которые работают с sessions на другой очереди, 
    // нужно пометить как nonisolated или использовать Task
    
    private nonisolated func getOrCreateSession(for uuid: NSUUID) {
        // ... код работы с session ...
        
        // При обновлении UI:
        Task { @MainActor in
            self.refreshSessionStatus(for: identifier, session: session, updateConnections: false)
        }
    }
}
```

**Файл:** `Sources/VPNBarApp/StatusBarController.swift`

```swift
@MainActor
class StatusBarController {
    // ... весь код класса ...
}
```

**Файл:** `Sources/VPNBarApp/MenuController.swift`

```swift
@MainActor
class MenuController {
    // ... весь код класса ...
}
```

**Файл:** `Sources/VPNBarApp/SettingsWindowController.swift`

```swift
@MainActor
class SettingsWindowController {
    // ... весь код класса ...
}
```

**Файл:** `Sources/VPNBarApp/SettingsManager.swift`

```swift
@MainActor
class SettingsManager {
    // ... весь код класса ...
}
```

---

### 3.3. Протоколы для Dependency Injection (подготовка к тестированию)

**Создать файл:** `Sources/VPNBarApp/Protocols/VPNManagerProtocol.swift`

```swift
import Foundation
import Combine

protocol VPNManagerProtocol: ObservableObject {
    var connections: [VPNConnection] { get }
    var hasActiveConnection: Bool { get }
    var loadingError: String? { get }
    var updateInterval: TimeInterval { get set }
    
    func loadConnections(forceReload: Bool)
    func connect(to connectionID: String)
    func disconnect(from connectionID: String)
    func toggleConnection(_ connectionID: String)
    func disconnectAll()
}
```

**Обновить VPNManager:**

```swift
@MainActor
class VPNManager: VPNManagerProtocol {
    // ... существующий код без изменений структуры ...
}
```

**Создать файл:** `Sources/VPNBarApp/Protocols/SettingsManagerProtocol.swift`

```swift
import Foundation

protocol SettingsManagerProtocol {
    var updateInterval: TimeInterval { get set }
    var hotkeyKeyCode: UInt32? { get set }
    var hotkeyModifiers: UInt32? { get set }
    var showNotifications: Bool { get set }
    var showConnectionName: Bool { get set }
    var launchAtLogin: Bool { get set }
    var isLaunchAtLoginAvailable: Bool { get }
    
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?)
}
```

---

## Часть 4: Обновление локализаций

**Файл:** `Sources/VPNBarApp/Resources/en.lproj/Localizable.strings`

Добавить все новые строки:

```
/* Notifications */
"VPN Connected" = "VPN Connected";
"VPN Disconnected" = "VPN Disconnected";
"Connected to %@" = "Connected to %@";
"Disconnected from %@" = "Disconnected from %@";

/* Errors */
"No VPN configurations found. Configure VPN in System Preferences → Network." = "No VPN configurations found. Configure VPN in System Preferences → Network.";
"Open Network Preferences..." = "Open Network Preferences...";

/* Hotkey validation */
"Invalid Hotkey" = "Invalid Hotkey";
"OK" = "OK";
"Hotkey must include at least one modifier key (⌘, ⌃, or ⌥)." = "Hotkey must include at least one modifier key (⌘, ⌃, or ⌥).";
"This key combination is reserved by the system. Please choose another." = "This key combination is reserved by the system. Please choose another.";

/* Settings - Startup */
"Startup" = "Startup";
"Launch at login" = "Launch at login";
"Automatically start VPN Bar when you log in." = "Automatically start VPN Bar when you log in.";
"(Requires macOS 13 or later)" = "(Requires macOS 13 or later)";

/* Menu */
"Disconnect All" = "Disconnect All";

/* Accessibility */
"VPN Status" = "VPN Status";
"Click to toggle VPN, right-click for menu" = "Click to toggle VPN, right-click for menu";
"Click to toggle connection" = "Click to toggle connection";
```

**Файл:** `Sources/VPNBarApp/Resources/ru.lproj/Localizable.strings`

Добавить все новые строки:

```
/* Notifications */
"VPN Connected" = "VPN подключён";
"VPN Disconnected" = "VPN отключён";
"Connected to %@" = "Подключено к %@";
"Disconnected from %@" = "Отключено от %@";

/* Errors */
"No VPN configurations found. Configure VPN in System Preferences → Network." = "VPN-подключения не найдены. Настройте VPN в Системных настройках → Сеть.";
"Open Network Preferences..." = "Открыть настройки сети...";

/* Hotkey validation */
"Invalid Hotkey" = "Некорректная комбинация";
"OK" = "ОК";
"Hotkey must include at least one modifier key (⌘, ⌃, or ⌥)." = "Комбинация должна содержать хотя бы одну клавишу-модификатор (⌘, ⌃ или ⌥).";
"This key combination is reserved by the system. Please choose another." = "Эта комбинация клавиш зарезервирована системой. Выберите другую.";

/* Settings - Startup */
"Startup" = "Запуск";
"Launch at login" = "Запускать при входе в систему";
"Automatically start VPN Bar when you log in." = "Автоматически запускать VPN Bar при входе в систему.";
"(Requires macOS 13 or later)" = "(Требуется macOS 13 или новее)";

/* Menu */
"Disconnect All" = "Отключить все";

/* Accessibility */
"VPN Status" = "Статус VPN";
"Click to toggle VPN, right-click for menu" = "Нажмите для переключения VPN, правый клик для меню";
"Click to toggle connection" = "Нажмите для переключения подключения";
```

---

## Часть 5: Обновление версии и документации

### 5.1. Обновить package_app.sh

```bash
# Изменить версию:
<key>CFBundleShortVersionString</key>
<string>0.3.0</string>
<key>CFBundleVersion</key>
<string>3</string>
```

### 5.2. Обновить README.md

Добавить в Changelog:

```markdown
### Version 0.3.0 (2025-XX-XX)

**Улучшения стабильности и UX**

#### Добавлено
- Поддержка "Запускать при входе в систему" (macOS 13+)
- Кнопка "Отключить все" для быстрого отключения всех VPN
- Анимация иконки при подключении/отключении VPN
- Валидация горячих клавиш (защита от системных комбинаций)
- Улучшенная поддержка Accessibility (VoiceOver)
- Информативные сообщения при отсутствии VPN-конфигураций
- Кнопка быстрого перехода в настройки сети

#### Исправлено
- Переход на современный UserNotifications API (исправлена работа уведомлений на macOS 11+)
- Исправлена потенциальная утечка памяти в HotkeyManager
- Устранены потенциальные краши из-за force unwrap
- Удалены deprecated вызовы synchronize()
- Оптимизирована частота обновления статуса VPN

#### Технические улучшения
- Добавлена поддержка @MainActor для thread safety
- Вынесены константы в отдельный файл AppConstants
- Вынесены Notification.Name в расширение
- Подготовлена архитектура для unit-тестирования (протоколы)
```

---

## Структура новых файлов

```
Sources/VPNBarApp/
├── AppConstants.swift                    # НОВЫЙ
├── AppDelegate.swift                     # ИЗМЕНЁН
├── HotkeyManager.swift                   # ИЗМЕНЁН
├── main.swift                            # БЕЗ ИЗМЕНЕНИЙ
├── MenuController.swift                  # ИЗМЕНЁН
├── NetworkExtensionBridge.swift          # БЕЗ ИЗМЕНЕНИЙ
├── NotificationManager.swift             # НОВЫЙ
├── SettingsManager.swift                 # ИЗМЕНЁН
├── SettingsWindowController.swift        # ИЗМЕНЁН
├── StatusBarController.swift             # ИЗМЕНЁН
├── VPNManager.swift                      # ИЗМЕНЁН
├── Extensions/
│   └── Notification+Extensions.swift     # НОВЫЙ
├── Models/
│   └── VPNConnection.swift               # БЕЗ ИЗМЕНЕНИЙ
├── Protocols/
│   ├── SettingsManagerProtocol.swift     # НОВЫЙ
│   └── VPNManagerProtocol.swift          # НОВЫЙ
└── Resources/
    ├── en.lproj/
    │   └── Localizable.strings           # ИЗМЕНЁН
    └── ru.lproj/
        └── Localizable.strings           # ИЗМЕНЁН
```

---

## Порядок реализации

1. **Фаза 1: Инфраструктура**
   - Создать `AppConstants.swift`
   - Создать `Extensions/Notification+Extensions.swift`
   - Обновить все файлы для использования новых констант

2. **Фаза 2: Критические исправления**
   - Создать `NotificationManager.swift`
   - Обновить `AppDelegate.swift` и `StatusBarController.swift`
   - Исправить `HotkeyManager.swift`
   - Исправить force unwrap в `SettingsWindowController.swift`
   - Удалить `synchronize()` из `SettingsManager.swift`

3. **Фаза 3: Новый функционал**
   - Добавить обработку ошибок в `VPNManager.swift` и `MenuController.swift`
   - Добавить валидацию горячих клавиш
   - Добавить Launch at Login
   - Добавить Disconnect All
   - Добавить анимацию

4. **Фаза 4: Улучшения качества**
   - Добавить `@MainActor`
   - Добавить Accessibility
   - Создать протоколы

5. **Фаза 5: Финализация**
   - Обновить локализации
   - Обновить версию
   - Обновить README.md
   - Тестирование

---

## Тестирование

После реализации проверить:

1. ✅ Уведомления работают на macOS 11+
2. ✅ Горячие клавиши регистрируются и работают
3. ✅ Валидация не позволяет установить Cmd+Q, просто "V" и т.д.
4. ✅ Launch at Login работает на macOS 13+
5. ✅ Анимация отображается при подключении
6. ✅ "Отключить все" отключает все VPN
7. ✅ VoiceOver корректно озвучивает элементы
8. ✅ Нет крашей при использовании
9. ✅ Локализация работает для EN и RU

