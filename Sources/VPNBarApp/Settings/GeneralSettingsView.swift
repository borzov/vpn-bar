import AppKit

/// General settings view component.
@MainActor
final class GeneralSettingsView: NSView {
    private var settingsManager: SettingsManagerProtocol
    private let vpnManager: VPNManagerProtocol
    
    var updateIntervalTextField: NSTextField?
    var showNotificationsCheckbox: NSButton?
    var showConnectionNameCheckbox: NSButton?
    var launchAtLoginCheckbox: NSButton?
    
    init(
        settingsManager: SettingsManagerProtocol,
        vpnManager: VPNManagerProtocol,
        frame: NSRect = .zero
    ) {
        self.settingsManager = settingsManager
        self.vpnManager = vpnManager
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
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        let startupSection = createStartupSection()
        mainStack.addArrangedSubview(startupSection)
        mainStack.addArrangedSubview(makeDivider())
        
        let intervalSection = createIntervalSection()
        mainStack.addArrangedSubview(intervalSection)
        mainStack.addArrangedSubview(makeDivider())
        
        let notificationsSection = createNotificationsSection()
        mainStack.addArrangedSubview(notificationsSection)
        mainStack.addArrangedSubview(makeDivider())
        
        let displaySection = createDisplaySection()
        mainStack.addArrangedSubview(displaySection)
        mainStack.addArrangedSubview(makeDivider())
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16),
            widthAnchor.constraint(equalToConstant: 556)
        ])
    }
    
    private func createIntervalSection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 6
        
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.status.title",
                comment: "Status update section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 6
        
        let textField = NSTextField()
        textField.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.alignment = .right
        textField.target = self
        textField.action = #selector(updateIntervalChanged(_:))
        textField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        self.updateIntervalTextField = textField
        inputStack.addArrangedSubview(textField)

        let stepper = NSStepper()
        stepper.minValue = AppConstants.minUpdateInterval
        stepper.maxValue = AppConstants.maxUpdateInterval
        stepper.increment = 1
        stepper.integerValue = Int(settingsManager.updateInterval)
        stepper.target = self
        stepper.action = #selector(updateIntervalChangedStepper(_:))
        inputStack.addArrangedSubview(stepper)
        
        let secondsLabel = NSTextField(
            labelWithString: NSLocalizedString(
                "settings.status.seconds",
                comment: "Label for seconds unit"
            )
        )
        secondsLabel.font = NSFont.systemFont(ofSize: 13)
        inputStack.addArrangedSubview(secondsLabel)
        
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 1).isActive = true
        inputStack.addArrangedSubview(spacer)
        
        sectionStack.addArrangedSubview(inputStack)
        
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
        
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.notifications.title",
                comment: "Notifications section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
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
        
        let description = makeDescriptionLabel(
            NSLocalizedString(
                "settings.notifications.description",
                comment: "Description for notifications toggle"
            )
        )
        sectionStack.addArrangedSubview(description)
        
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
        
        let sectionLabel = makeSectionLabel(
            NSLocalizedString(
                "settings.display.title",
                comment: "Display section title"
            )
        )
        sectionStack.addArrangedSubview(sectionLabel)
        
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
        
        if !settingsManager.isLaunchAtLoginAvailable {
            checkbox.isEnabled = false
        }
        
        self.launchAtLoginCheckbox = checkbox
        sectionStack.addArrangedSubview(checkbox)
        
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
    
    @objc private func updateIntervalChanged(_ sender: NSTextField) {
        guard let text = Double(sender.stringValue.trimmingCharacters(in: .whitespaces)) else {
            sender.stringValue = String(format: "%.0f", settingsManager.updateInterval)
            return
        }
        
        let validatedValue = text.clamped(to: AppConstants.minUpdateInterval...AppConstants.maxUpdateInterval)
        if validatedValue != text {
            sender.stringValue = String(format: "%.0f", validatedValue)
        }
        
        vpnManager.updateInterval = validatedValue
    }
    
    @objc private func updateIntervalChangedStepper(_ sender: NSStepper) {
        let value = sender.integerValue
        updateIntervalTextField?.stringValue = "\(value)"
        updateIntervalChanged(updateIntervalTextField ?? NSTextField(string: "\(value)"))
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
    
    func updateIntervalDidChange() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
    }
    
    func syncUI() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        showNotificationsCheckbox?.state = settingsManager.showNotifications ? .on : .off
        showConnectionNameCheckbox?.state = settingsManager.showConnectionName ? .on : .off
        launchAtLoginCheckbox?.state = settingsManager.launchAtLogin ? .on : .off
    }
    
    private func makeDivider() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
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
