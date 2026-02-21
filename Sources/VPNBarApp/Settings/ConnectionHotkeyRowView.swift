import AppKit

/// A row view for per-connection hotkey assignment in settings.
@MainActor
final class ConnectionHotkeyRowView: NSView {
    let hotkeyButton: NSButton
    private var clearButton: NSButton?
    private let connectionID: String

    var onRecord: ((String) -> Void)?
    var onClear: ((String) -> Void)?

    init(connectionName: String, connectionID: String, hasHotkey: Bool) {
        self.connectionID = connectionID
        self.hotkeyButton = NSButton()
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let rowStack = NSStackView()
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.distribution = .fill
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: connectionName)
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        rowStack.addArrangedSubview(nameLabel)

        hotkeyButton.bezelStyle = .recessed
        hotkeyButton.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        hotkeyButton.focusRingType = .none
        hotkeyButton.wantsLayer = true
        hotkeyButton.layer?.cornerRadius = 6
        hotkeyButton.layer?.borderWidth = 1
        hotkeyButton.layer?.borderColor = NSColor.separatorColor.cgColor
        hotkeyButton.contentTintColor = .secondaryLabelColor
        hotkeyButton.setButtonType(.momentaryPushIn)
        hotkeyButton.target = self
        hotkeyButton.action = #selector(recordButtonClicked(_:))
        rowStack.addArrangedSubview(hotkeyButton)

        if hasHotkey {
            let btn = makeClearButton()
            clearButton = btn
            rowStack.addArrangedSubview(btn)
        }

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func recordButtonClicked(_ sender: NSButton) {
        onRecord?(connectionID)
    }

    @objc private func clearButtonClicked(_ sender: NSButton) {
        onClear?(connectionID)
    }

    func updateClearButtonVisibility(hasHotkey: Bool) {
        if hasHotkey && clearButton == nil {
            if let stack = hotkeyButton.superview as? NSStackView {
                let btn = makeClearButton()
                clearButton = btn
                stack.addArrangedSubview(btn)
            }
        } else if !hasHotkey, let btn = clearButton {
            btn.removeFromSuperview()
            clearButton = nil
        }
    }

    private func makeClearButton() -> NSButton {
        let btn = NSButton()
        btn.title = ""
        btn.bezelStyle = .texturedRounded
        btn.target = self
        btn.action = #selector(clearButtonClicked(_:))
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
        btn.imagePosition = .imageOnly
        btn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        btn.isBordered = false
        btn.contentTintColor = .secondaryLabelColor
        return btn
    }
}
