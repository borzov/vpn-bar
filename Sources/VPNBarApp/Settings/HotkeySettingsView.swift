import AppKit
import Carbon

/// Hotkey settings view component.
@MainActor
final class HotkeySettingsView: NSView {
    private let settingsManager: SettingsManagerProtocol
    
    var hotkeyButton: NSButton?
    var hotkeyValidationLabel: NSTextField?
    var clearHotkeyButton: NSButton?
    
    var isRecordingHotkey = false
    private var recordedKeyCode: UInt32?
    private var recordedModifiers: UInt32 = 0
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    var onHotkeyChanged: (() -> Void)?
    
    init(settingsManager: SettingsManagerProtocol, frame: NSRect = .zero) {
        self.settingsManager = settingsManager
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.distribution = .fill
        mainStack.spacing = 14
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        let toggleSection = createToggleHotkeySection()
        mainStack.addArrangedSubview(toggleSection)
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            widthAnchor.constraint(equalToConstant: 556)
        ])
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
        
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 8
        
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
        
        updateHotkeyButtonTitle(hotkeyButton)
        
        self.hotkeyButton = hotkeyButton
        inputStack.addArrangedSubview(hotkeyButton)
        
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

        let validationLabel = NSTextField(labelWithString: "")
        validationLabel.font = NSFont.systemFont(ofSize: 11)
        validationLabel.textColor = .systemRed
        validationLabel.isHidden = true
        validationLabel.preferredMaxLayoutWidth = 520
        validationLabel.lineBreakMode = .byWordWrapping
        sectionStack.addArrangedSubview(validationLabel)
        self.hotkeyValidationLabel = validationLabel

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
            
            if keyCode == KeyCode.escape.rawValue {
                stopRecordingHotkey()
                if let button = hotkeyButton {
                    updateHotkeyButtonTitle(button)
                }
                clearValidationMessage()
                hotkeyButton?.layer?.borderColor = NSColor.separatorColor.cgColor
                hotkeyButton?.layer?.backgroundColor = NSColor.clear.cgColor
                return
            }
            
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
            
            if !hasRequiredModifiers(carbonModifiers) {
                showHotkeyValidationError(
                    NSLocalizedString(
                        "settings.hotkey.validation.missingModifier",
                        comment: "Validation error when no required modifier in hotkey"
                    )
                )
                return
            }
            
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
            
            stopRecordingHotkey()
            saveHotkey()
        }
    }
    
    private func isSystemReservedHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let reservedHotkeys: [(keyCode: UInt32, modifiers: UInt32)] = [
            (12, UInt32(cmdKey)),
            (13, UInt32(cmdKey)),
            (48, UInt32(cmdKey)),
            (49, UInt32(cmdKey)),
            (4, UInt32(cmdKey)),
            (46, UInt32(cmdKey)),
            (43, UInt32(cmdKey)),
            (12, UInt32(cmdKey) | UInt32(controlKey)),
            (12, UInt32(cmdKey) | UInt32(shiftKey)),
        ]
        
        return reservedHotkeys.contains { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }
    
    private func hasRequiredModifiers(_ modifiers: UInt32) -> Bool {
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
        
        clearHotkeyButton?.removeFromSuperview()
        clearHotkeyButton = nil
        onHotkeyChanged?()
    }
    
    private func saveHotkey() {
        guard let keyCode = recordedKeyCode else { return }
        
        settingsManager.saveHotkey(keyCode: keyCode, modifiers: recordedModifiers)
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        clearValidationMessage()
        updateHotkeyUI()
        onHotkeyChanged?()
    }
    
    private func formatHotkey(keyCode: UInt32?, modifiers: UInt32?) -> String {
        guard let keyCode = keyCode, let modifiers = modifiers else { return "" }
        
        var parts: [String] = []
        
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
    
    private func updateHotkeyUI() {
        if settingsManager.hotkeyKeyCode != nil && clearHotkeyButton == nil {
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
    
    func hotkeyDidChange() {
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
        onHotkeyChanged?()
    }
    
    func syncUI() {
        if let button = hotkeyButton {
            updateHotkeyButtonTitle(button)
        }
    }
    
    deinit {
        isRecordingHotkey = false
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func makeSectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        return label
    }
    
    private func makeDescriptionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 524
        return label
    }
}
