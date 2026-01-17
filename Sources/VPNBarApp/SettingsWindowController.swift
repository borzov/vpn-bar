import AppKit
import Combine
import Carbon

/// Контролирует окно настроек и запись глобальных горячих клавиш.
@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var updateIntervalTextField: NSTextField?
    private var hotkeyButton: NSButton?
    private var hotkeyValidationLabel: NSTextField?
    private var showNotificationsCheckbox: NSButton?
    private var showConnectionNameCheckbox: NSButton?
    private var launchAtLoginCheckbox: NSButton?
    private var isRecordingHotkey = false
    private var recordedKeyCode: UInt32?
    private var recordedModifiers: UInt32 = 0
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var clearHotkeyButton: NSButton?
    private let vpnManager: VPNManagerProtocol
    private var settingsManager: SettingsManagerProtocol
    
    init(
        vpnManager: VPNManagerProtocol = VPNManager.shared,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.vpnManager = vpnManager
        self.settingsManager = settingsManager
        createWindow()
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = NSLocalizedString(
            "settings.title.preferences",
            comment: "Title for the preferences window"
        )
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
        generalTab.label = NSLocalizedString("settings.tab.general", comment: "General tab title")
        generalTab.view = createGeneralView()
        tabView.addTabViewItem(generalTab)
        
        // Вкладка Hotkeys
        let hotkeysTab = NSTabViewItem(identifier: "hotkeys")
        hotkeysTab.label = NSLocalizedString("settings.tab.hotkeys", comment: "Hotkeys tab title")
        hotkeysTab.view = createHotkeysView()
        tabView.addTabViewItem(hotkeysTab)

        // Вкладка About
        let aboutTab = NSTabViewItem(identifier: "about")
        aboutTab.label = NSLocalizedString("settings.tab.about", comment: "About tab title")
        aboutTab.view = createAboutView()
        tabView.addTabViewItem(aboutTab)
        
        contentView.addSubview(tabView)
        
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        
        window.contentView = contentView
        self.window = window
        
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
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Секция: Запуск
        let startupSection = createStartupSection()
        mainStack.addArrangedSubview(startupSection)
        mainStack.addArrangedSubview(makeDivider())
        
        // Секция: Интервал обновления
        let intervalSection = createIntervalSection()
        mainStack.addArrangedSubview(intervalSection)
        mainStack.addArrangedSubview(makeDivider())
        
        // Секция: Уведомления
        let notificationsSection = createNotificationsSection()
        mainStack.addArrangedSubview(notificationsSection)
        mainStack.addArrangedSubview(makeDivider())
        
        // Секция: Отображение
        let displaySection = createDisplaySection()
        mainStack.addArrangedSubview(displaySection)
        mainStack.addArrangedSubview(makeDivider())
        
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
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.status.title",
                comment: "Status update section title"
            )
        )
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

        // Степпер
        let stepper = NSStepper()
        stepper.minValue = AppConstants.minUpdateInterval
        stepper.maxValue = AppConstants.maxUpdateInterval
        stepper.increment = 1
        stepper.integerValue = Int(settingsManager.updateInterval)
        stepper.target = self
        stepper.action = #selector(updateIntervalChangedStepper(_:))
        inputStack.addArrangedSubview(stepper)
        
        // Метка "секунд"
        let secondsLabel = NSTextField(
            labelWithString: NSLocalizedString(
                "settings.status.seconds",
                comment: "Label for seconds unit"
            )
        )
        secondsLabel.font = NSFont.systemFont(ofSize: 13)
        inputStack.addArrangedSubview(secondsLabel)
        
        // Spacer
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 1).isActive = true
        inputStack.addArrangedSubview(spacer)
        
        sectionStack.addArrangedSubview(inputStack)
        
        // Описание
        let description = makeDescriptionLabel(
            NSLocalizedString(
                "settings.status.description",
                comment: "Description for status update interval"
            )
        )
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
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.notifications.title",
                comment: "Notifications section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Чекбокс
        let checkbox = NSButton(
            checkboxWithTitle: NSLocalizedString(
                "settings.notifications.toggle",
                comment: "Toggle to show notifications on connect/disconnect"
            ),
            target: self,
            action: #selector(showNotificationsChanged(_:))
        )
        checkbox.state = settingsManager.showNotifications ? .on : .off
        checkbox.font = NSFont.systemFont(ofSize: 13)
        self.showNotificationsCheckbox = checkbox
        sectionStack.addArrangedSubview(checkbox)
        
        // Описание
        let description = makeDescriptionLabel(
            NSLocalizedString(
                "settings.notifications.description",
                comment: "Description for notifications toggle"
            )
        )
        sectionStack.addArrangedSubview(description)
        
        // Чекбокс для звуковой обратной связи
        let soundCheckbox = NSButton(
            checkboxWithTitle: NSLocalizedString(
                "settings.notifications.soundFeedback",
                comment: "Toggle to enable sound feedback"
            ),
            target: self,
            action: #selector(soundFeedbackChanged(_:))
        )
        soundCheckbox.state = settingsManager.soundFeedbackEnabled ? .on : .off
        soundCheckbox.font = NSFont.systemFont(ofSize: 13)
        sectionStack.addArrangedSubview(soundCheckbox)
        
        // Описание для звуковой обратной связи
        let soundDescription = makeDescriptionLabel(
            NSLocalizedString(
                "settings.notifications.soundFeedbackDescription",
                comment: "Description for sound feedback toggle"
            )
        )
        sectionStack.addArrangedSubview(soundDescription)
        
        return sectionStack
    }
    
    private func createDisplaySection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        // Заголовок секции
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.display.title",
                comment: "Display section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Чекбокс
        let checkbox = NSButton(
            checkboxWithTitle: NSLocalizedString(
                "settings.display.showName",
                comment: "Toggle to show connection name in tooltip"
            ),
            target: self,
            action: #selector(showConnectionNameChanged(_:))
        )
        checkbox.state = settingsManager.showConnectionName ? .on : .off
        checkbox.font = NSFont.systemFont(ofSize: 13)
        self.showConnectionNameCheckbox = checkbox
        sectionStack.addArrangedSubview(checkbox)
        
        // Описание
        let description = makeDescriptionLabel(
            NSLocalizedString(
                "settings.display.description",
                comment: "Description for showing connection name"
            )
        )
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
    private func createStartupSection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.startup.title",
                comment: "Startup section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
        let checkbox = NSButton(
            checkboxWithTitle: NSLocalizedString(
                "settings.startup.launchAtLogin",
                comment: "Toggle to launch app at login"
            ),
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
        var descriptionText = NSLocalizedString(
            "settings.startup.description",
            comment: "Description for launch at login toggle"
        )
        if !settingsManager.isLaunchAtLoginAvailable {
            descriptionText += " " + NSLocalizedString(
                "settings.startup.requires13",
                comment: "Note about macOS version requirement"
            )
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
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
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
    
    private func createToggleHotkeySection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 8
        
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.hotkey.title",
                comment: "Hotkey section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Горизонтальный стек для кнопки горячей клавиши и кнопки очистки
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 8
        
        // Кнопка для отображения/записи горячей клавиши (как в Shottr)
        let hotkeyButton = NSButton()
        hotkeyButton.bezelStyle = .recessed
        hotkeyButton.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        hotkeyButton.focusRingType = .none
        hotkeyButton.wantsLayer = true
        hotkeyButton.layer?.cornerRadius = 6
        hotkeyButton.layer?.borderWidth = 1
        hotkeyButton.layer?.borderColor = NSColor.separatorColor.cgColor
        hotkeyButton.contentTintColor = .secondaryLabelColor
        hotkeyButton.setButtonType(.momentaryPushIn)
        hotkeyButton.target = self
        hotkeyButton.action = #selector(hotkeyButtonClicked(_:))
        
        // Устанавливаем текст кнопки
        updateHotkeyButtonTitle(hotkeyButton)
        
        self.hotkeyButton = hotkeyButton
        inputStack.addArrangedSubview(hotkeyButton)
        
        // Кнопка очистки (если есть горячая клавиша)
        if settingsManager.hotkeyKeyCode != nil {
            let clearButton = NSButton()
            clearButton.title = ""
            clearButton.bezelStyle = .texturedRounded
            clearButton.target = self
            clearButton.action = #selector(clearHotkey(_:))
            clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
            clearButton.imagePosition = .imageOnly
            clearButton.widthAnchor.constraint(equalToConstant: 22).isActive = true
            clearButton.heightAnchor.constraint(equalToConstant: 22).isActive = true
            clearButton.isBordered = false
            clearButton.contentTintColor = .secondaryLabelColor
            self.clearHotkeyButton = clearButton
            inputStack.addArrangedSubview(clearButton)
        } else {
            self.clearHotkeyButton = nil
        }
        
        sectionStack.addArrangedSubview(inputStack)

        // Inline-валидация (скрыта по умолчанию)
        let validationLabel = NSTextField(labelWithString: "")
        validationLabel.font = NSFont.systemFont(ofSize: 11)
        validationLabel.textColor = .systemRed
        validationLabel.isHidden = true
        validationLabel.preferredMaxLayoutWidth = 520
        validationLabel.lineBreakMode = .byWordWrapping
        sectionStack.addArrangedSubview(validationLabel)
        self.hotkeyValidationLabel = validationLabel

        // Описание
        let description = makeDescriptionLabel(
            NSLocalizedString(
                "settings.hotkey.description",
                comment: "Description for global VPN toggle hotkey"
            )
        )
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
            button.layer?.borderColor = NSColor.separatorColor.cgColor
        } else {
            button.title = NSLocalizedString(
                "settings.hotkey.record",
                comment: "Button title to start recording shortcut"
            )
            button.contentTintColor = .secondaryLabelColor
            button.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
    
    @objc private func showNotificationsChanged(_ sender: NSButton) {
        settingsManager.showNotifications = sender.state == .on
    }
    
    @objc private func soundFeedbackChanged(_ sender: NSButton) {
        settingsManager.soundFeedbackEnabled = sender.state == .on
    }
    
    @objc private func showConnectionNameChanged(_ sender: NSButton) {
        settingsManager.showConnectionName = sender.state == .on
    }
    
    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        settingsManager.launchAtLogin = sender.state == .on
    }
    
    private func startRecordingHotkey() {
        isRecordingHotkey = true
        recordedKeyCode = nil
        recordedModifiers = 0
        clearValidationMessage()
        hotkeyButton?.title = NSLocalizedString(
            "settings.hotkey.pressKeys",
            comment: "Button title while recording shortcut"
        )
        hotkeyButton?.contentTintColor = .controlAccentColor
        hotkeyButton?.layer?.borderColor = NSColor.controlAccentColor.cgColor
        hotkeyButton?.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        
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
            if keyCode == KeyCode.escape.rawValue {
                stopRecordingHotkey()
                // Восстанавливаем предыдущее значение
                if let button = hotkeyButton {
                    updateHotkeyButtonTitle(button)
                }
                clearValidationMessage()
                hotkeyButton?.layer?.borderColor = NSColor.separatorColor.cgColor
                hotkeyButton?.layer?.backgroundColor = NSColor.clear.cgColor
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
            
            // Валидация: требуется хотя бы один модификатор
            if !hasRequiredModifiers(carbonModifiers) {
                showHotkeyValidationError(
                    NSLocalizedString(
                        "settings.hotkey.validation.missingModifier",
                        comment: "Validation error when no required modifier in hotkey"
                    )
                )
                return
            }
            
            // Валидация: не используем системные комбинации
            if isSystemReservedHotkey(keyCode: keyCode, modifiers: carbonModifiers) {
                showHotkeyValidationError(
                    NSLocalizedString(
                        "settings.hotkey.validation.reserved",
                        comment: "Validation error when hotkey is system-reserved"
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
    
    private func showHotkeyValidationError(_ message: String) {
        if let label = hotkeyValidationLabel {
            label.stringValue = message
            label.isHidden = false
        }
        hotkeyButton?.layer?.borderColor = NSColor.systemRed.cgColor
    }
    
    private func stopRecordingHotkey() {
        isRecordingHotkey = false
        
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
            button.contentTintColor = .labelColor
            button.layer?.borderColor = NSColor.separatorColor.cgColor
            button.layer?.backgroundColor = NSColor.clear.cgColor
        }
        clearValidationMessage()
        
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
        clearValidationMessage()
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
            parts.append(
                String(
                    format: NSLocalizedString(
                        "settings.hotkey.keyPlaceholder",
                        comment: "Fallback label for a key code"
                    ),
                    keyCode
                )
            )
        }
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        return KeyCode(rawValue: keyCode)?.stringValue
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

    private func clearValidationMessage() {
        if let label = hotkeyValidationLabel {
            label.stringValue = ""
            label.isHidden = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Останавливаем запись напрямую
        isRecordingHotkey = false
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    @objc private func updateIntervalChanged(_ sender: NSTextField) {
        guard let text = Double(sender.stringValue.trimmingCharacters(in: .whitespaces)) else {
            sender.stringValue = String(format: "%.0f", settingsManager.updateInterval)
            return
        }
        
        let validatedValue = text.clamped(to: AppConstants.minUpdateInterval...AppConstants.maxUpdateInterval)
        if validatedValue != text {
            sender.stringValue = String(format: "%.0f", validatedValue)
        }
        
        // Используем VPNManager для обновления интервала, который обновит SettingsManager
        vpnManager.updateInterval = validatedValue
    }
    
    @objc private func updateIntervalDidChange() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
    }

    @objc private func updateIntervalChangedStepper(_ sender: NSStepper) {
        let value = sender.integerValue
        updateIntervalTextField?.stringValue = "\(value)"
        updateIntervalChanged(updateIntervalTextField ?? NSTextField(string: "\(value)"))
    }
    
    @objc private func hotkeyDidChange() {
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        registerHotkey()
    }
    
    /// Показывает окно настроек и синхронизирует элементы управления с текущими значениями.
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

    private func createAboutView() -> NSView {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: Bundle.main.appName)
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let descriptionLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("settings.about.description", comment: "About description"))
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.preferredMaxLayoutWidth = 520

        let versionString = Bundle.main.formattedVersion
        let versionLabel = NSTextField(labelWithString: String(
            format: NSLocalizedString("settings.about.version", comment: "App version label"),
            versionString
        ))
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor

        let authorLabel = NSTextField(labelWithString: NSLocalizedString("settings.about.author", comment: "Author info"))
        authorLabel.font = NSFont.systemFont(ofSize: 12)
        authorLabel.textColor = .secondaryLabelColor

        let repoButton = NSButton()
        repoButton.title = NSLocalizedString("settings.about.repoButton", comment: "Open repository button")
        repoButton.bezelStyle = .rounded
        repoButton.target = self
        repoButton.action = #selector(openRepository(_:))

        [title, descriptionLabel, versionLabel, authorLabel, repoButton].forEach { stack.addArrangedSubview($0) }

        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])

        return contentView
    }

    @objc private func openRepository(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.URLs.repository)
    }

    private func makeDivider() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }
    
    /// Creates a section label with consistent styling.
    /// - Parameter text: Label text.
    /// - Returns: Configured NSTextField.
    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return label
    }
    
    /// Creates a description label with consistent styling.
    /// - Parameter text: Description text.
    /// - Returns: Configured NSTextField.
    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 524
        return label
    }
}