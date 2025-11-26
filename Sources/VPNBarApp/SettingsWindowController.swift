import AppKit
import Combine
import Carbon

class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var tabView: NSTabView?
    private var updateIntervalTextField: NSTextField?
    private var hotkeyButton: NSButton?
    private var showNotificationsCheckbox: NSButton?
    private var showConnectionNameCheckbox: NSButton?
    private var launchAtLoginCheckbox: NSButton?
    private var isRecordingHotkey = false
    private var recordedKeyCode: UInt32?
    private var recordedModifiers: UInt32 = 0
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var clearHotkeyButton: NSButton?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager = VPNManager.shared
    private let settingsManager = SettingsManager.shared
    
    private init() {
        createWindow()
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = NSLocalizedString("Preferences", comment: "")
        window.center()
        window.isReleasedWhenClosed = false
        
        // Создаем главный контейнер
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        // Создаем TabView
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        // Вкладка General
        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = NSLocalizedString("General", comment: "")
        generalTab.view = createGeneralView()
        tabView.addTabViewItem(generalTab)
        
        // Вкладка Hotkeys
        let hotkeysTab = NSTabViewItem(identifier: "hotkeys")
        hotkeysTab.label = NSLocalizedString("Hotkeys", comment: "")
        hotkeysTab.view = createHotkeysView()
        tabView.addTabViewItem(hotkeysTab)
        
        contentView.addSubview(tabView)
        
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        window.contentView = contentView
        self.window = window
        self.tabView = tabView
        
        // Подписки на изменения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIntervalDidChange),
            name: .updateIntervalDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
    }
    
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
        
        // Секция: Уведомления
        let notificationsSection = createNotificationsSection()
        mainStack.addArrangedSubview(notificationsSection)
        
        // Секция: Отображение
        let displaySection = createDisplaySection()
        mainStack.addArrangedSubview(displaySection)
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalToConstant: 556)
        ])
        
        return contentView
    }
    
    private func createIntervalSection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        // Заголовок секции
        let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Status Update Interval", comment: ""))
        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Горизонтальный стек для поля ввода
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 6
        
        // Текстовое поле
        let textField = NSTextField()
        textField.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.alignment = .right
        textField.target = self
        textField.action = #selector(updateIntervalChanged(_:))
        textField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        self.updateIntervalTextField = textField
        inputStack.addArrangedSubview(textField)
        
        // Метка "секунд"
        let secondsLabel = NSTextField(labelWithString: NSLocalizedString("seconds", comment: ""))
        secondsLabel.font = NSFont.systemFont(ofSize: 13)
        inputStack.addArrangedSubview(secondsLabel)
        
        // Spacer
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 1).isActive = true
        inputStack.addArrangedSubview(spacer)
        
        sectionStack.addArrangedSubview(inputStack)
        
        // Описание
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Status Update Interval Description", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 524
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
    private func createNotificationsSection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        // Заголовок секции
        let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Notifications", comment: ""))
        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Чекбокс
        let checkbox = NSButton(checkboxWithTitle: NSLocalizedString("Show notifications when VPN connects or disconnects", comment: ""), target: self, action: #selector(showNotificationsChanged(_:)))
        checkbox.state = settingsManager.showNotifications ? .on : .off
        checkbox.font = NSFont.systemFont(ofSize: 13)
        self.showNotificationsCheckbox = checkbox
        sectionStack.addArrangedSubview(checkbox)
        
        // Описание
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Show notifications description", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 524
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
    private func createDisplaySection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        // Заголовок секции
        let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Display", comment: ""))
        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Чекбокс
        let checkbox = NSButton(checkboxWithTitle: NSLocalizedString("Show connection name in tooltip", comment: ""), target: self, action: #selector(showConnectionNameChanged(_:)))
        checkbox.state = settingsManager.showConnectionName ? .on : .off
        checkbox.font = NSFont.systemFont(ofSize: 13)
        self.showConnectionNameCheckbox = checkbox
        sectionStack.addArrangedSubview(checkbox)
        
        // Описание
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Show connection name description", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 524
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
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
    
    private func createHotkeysView() -> NSView {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.distribution = .fill
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Секция с инструкциями
        let instructionsSection = createInstructionsSection()
        mainStack.addArrangedSubview(instructionsSection)
        
        // Секция: Toggle VPN
        let toggleSection = createToggleHotkeySection()
        mainStack.addArrangedSubview(toggleSection)
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalToConstant: 556)
        ])
        
        return contentView
    }
    
    private func createInstructionsSection() -> NSView {
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Hotkeys work globally and allow you to toggle VPN connection from anywhere in the system.", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 524
        description.translatesAutoresizingMaskIntoConstraints = false
        
        return description
    }
    
    private func createToggleHotkeySection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        // Заголовок секции
        let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Toggle VPN Connection", comment: ""))
        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Горизонтальный стек для кнопки горячей клавиши и кнопки очистки
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 8
        
        // Кнопка для отображения/записи горячей клавиши (как в Shottr)
        let hotkeyButton = NSButton()
        hotkeyButton.bezelStyle = .rounded
        hotkeyButton.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        hotkeyButton.target = self
        hotkeyButton.action = #selector(hotkeyButtonClicked(_:))
        
        // Устанавливаем текст кнопки
        updateHotkeyButtonTitle(hotkeyButton)
        
        self.hotkeyButton = hotkeyButton
        inputStack.addArrangedSubview(hotkeyButton)
        
        // Кнопка очистки (если есть горячая клавиша)
        if settingsManager.hotkeyKeyCode != nil {
            let clearButton = NSButton()
            clearButton.title = "×"
            clearButton.bezelStyle = .circular
            clearButton.target = self
            clearButton.action = #selector(clearHotkey(_:))
            clearButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
            clearButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
            clearButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            self.clearHotkeyButton = clearButton
            inputStack.addArrangedSubview(clearButton)
        } else {
            self.clearHotkeyButton = nil
        }
        
        sectionStack.addArrangedSubview(inputStack)
        
        // Описание
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Toggle VPN Hotkey Description", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 524
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
    @objc private func hotkeyButtonClicked(_ sender: NSButton) {
        if !isRecordingHotkey {
            startRecordingHotkey()
        }
    }
    
    private func updateHotkeyButtonTitle(_ button: NSButton) {
        if let keyCode = settingsManager.hotkeyKeyCode, let modifiers = settingsManager.hotkeyModifiers {
            let hotkeyString = formatHotkey(keyCode: keyCode, modifiers: modifiers)
            button.title = hotkeyString
            button.contentTintColor = .labelColor
        } else {
            button.title = NSLocalizedString("Record Shortcut", comment: "")
            button.contentTintColor = .secondaryLabelColor
        }
    }
    
    @objc private func showNotificationsChanged(_ sender: NSButton) {
        settingsManager.showNotifications = sender.state == .on
    }
    
    @objc private func showConnectionNameChanged(_ sender: NSButton) {
        settingsManager.showConnectionName = sender.state == .on
    }
    
    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        settingsManager.launchAtLogin = sender.state == .on
    }
    
    @objc private func recordHotkey(_ sender: NSButton) {
        if isRecordingHotkey {
            stopRecordingHotkey()
        } else {
            startRecordingHotkey()
        }
    }
    
    private func startRecordingHotkey() {
        isRecordingHotkey = true
        recordedKeyCode = nil
        recordedModifiers = 0
        hotkeyButton?.title = NSLocalizedString("Press keys...", comment: "")
        hotkeyButton?.contentTintColor = .systemBlue
        
        // Устанавливаем глобальный монитор событий
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleHotkeyEvent(event)
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handleHotkeyEvent(event)
            return nil
        }
    }
    
    private func handleHotkeyEvent(_ event: NSEvent) {
        guard isRecordingHotkey else { return }
        
        if event.type == .keyDown {
            let keyCode = UInt32(event.keyCode)
            
            // Escape отменяет запись
            if keyCode == 53 { // Escape key
                stopRecordingHotkey()
                // Восстанавливаем предыдущее значение
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
    
    @objc private func clearHotkey(_ sender: NSButton) {
        settingsManager.saveHotkey(keyCode: nil, modifiers: nil)
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        HotkeyManager.shared.unregisterHotkey()
        
        // Удаляем кнопку очистки из UI
        clearHotkeyButton?.removeFromSuperview()
        clearHotkeyButton = nil
    }
    
    private func saveHotkey() {
        guard let keyCode = recordedKeyCode else { return }
        
        settingsManager.saveHotkey(keyCode: keyCode, modifiers: recordedModifiers)
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        updateHotkeyUI()
        registerHotkey()
    }
    
    private func formatHotkey(keyCode: UInt32?, modifiers: UInt32?) -> String {
        guard let keyCode = keyCode, let modifiers = modifiers else { return "" }
        
        var parts: [String] = []
        
        // Проверяем Carbon модификаторы
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        
        // Преобразуем keyCode в символ
        if let keyChar = keyCodeToString(keyCode) {
            parts.append(keyChar)
        } else {
            parts.append("Key \(keyCode)")
        }
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        // Базовые клавиши
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
            38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
            36: "↩", 48: "⇥", 49: "␣", 51: "⌫", 53: "⎋",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";",
            42: "\\", 43: ",", 44: "/", 47: "."
        ]
        
        return keyMap[keyCode]
    }
    
    private func registerHotkey() {
        guard let keyCode = settingsManager.hotkeyKeyCode,
              let modifiers = settingsManager.hotkeyModifiers else {
            return
        }
        
        HotkeyManager.shared.registerHotkey(keyCode: keyCode, modifiers: modifiers) {
            StatusBarController.shared?.toggleVPNConnection()
        }
    }
    
    private func updateHotkeyUI() {
        // Обновляем кнопку очистки
        if settingsManager.hotkeyKeyCode != nil && clearHotkeyButton == nil {
            // Добавляем кнопку очистки, если её нет
            if let inputStack = hotkeyButton?.superview as? NSStackView {
                let clearButton = NSButton()
                clearButton.title = "×"
                clearButton.bezelStyle = .circular
                clearButton.target = self
                clearButton.action = #selector(clearHotkey(_:))
                clearButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
                clearButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
                clearButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                self.clearHotkeyButton = clearButton
                inputStack.addArrangedSubview(clearButton)
            }
        } else if settingsManager.hotkeyKeyCode == nil && clearHotkeyButton != nil {
            // Удаляем кнопку очистки, если горячей клавиши нет
            clearHotkeyButton?.removeFromSuperview()
            clearHotkeyButton = nil
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopRecordingHotkey()
    }
    
    @objc private func updateIntervalChanged(_ sender: NSTextField) {
        guard let text = Double(sender.stringValue.trimmingCharacters(in: .whitespaces)) else {
            sender.stringValue = String(format: "%.0f", settingsManager.updateInterval)
            return
        }
        
        let validatedValue = max(5.0, min(60.0, text))
        if validatedValue != text {
            sender.stringValue = String(format: "%.0f", validatedValue)
        }
        
        settingsManager.updateInterval = validatedValue
        vpnManager.updateInterval = validatedValue
    }
    
    @objc private func updateIntervalDidChange() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
    }
    
    @objc private func hotkeyDidChange() {
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        registerHotkey()
    }
    
    func showWindow() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        showNotificationsCheckbox?.state = settingsManager.showNotifications ? .on : .off
        showConnectionNameCheckbox?.state = settingsManager.showConnectionName ? .on : .off
        launchAtLoginCheckbox?.state = settingsManager.launchAtLogin ? .on : .off
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
