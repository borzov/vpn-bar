import AppKit

/// About settings view component.
@MainActor
final class AboutSettingsView: NSView {
    override init(frame: NSRect = .zero) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

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

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    @objc private func openRepository(_ sender: Any) {
        NSWorkspace.shared.open(AppConstants.URLs.repository)
    }
}
