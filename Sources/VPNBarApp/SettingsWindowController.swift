import AppKit

/// Controls the settings window and coordinates settings views.
@MainActor
class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var generalView: GeneralSettingsView?
    private var hotkeyView: HotkeySettingsView?
    private let vpnManager: VPNManagerProtocol
    private let settingsManager: SettingsManagerProtocol
    
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
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        
        let generalView = GeneralSettingsView(
            settingsManager: settingsManager,
            vpnManager: vpnManager
        )
        self.generalView = generalView
        
        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = NSLocalizedString("settings.tab.general", comment: "General tab title")
        generalTab.view = generalView
        tabView.addTabViewItem(generalTab)
        
        let hotkeyView = HotkeySettingsView(settingsManager: settingsManager)
        hotkeyView.onHotkeyChanged = { [weak self] in
            self?.registerHotkey()
        }
        self.hotkeyView = hotkeyView
        
        let hotkeysTab = NSTabViewItem(identifier: "hotkeys")
        hotkeysTab.label = NSLocalizedString("settings.tab.hotkeys", comment: "Hotkeys tab title")
        hotkeysTab.view = hotkeyView
        tabView.addTabViewItem(hotkeysTab)

        let aboutView = AboutSettingsView()
        let aboutTab = NSTabViewItem(identifier: "about")
        aboutTab.label = NSLocalizedString("settings.tab.about", comment: "About tab title")
        aboutTab.view = aboutView
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
    
    @objc private func updateIntervalDidChange() {
        generalView?.updateIntervalDidChange()
    }
    
    @objc private func hotkeyDidChange() {
        hotkeyView?.hotkeyDidChange()
        registerHotkey()
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
    
    /// Shows the settings window and synchronizes controls with current values.
    func showWindow() {
        generalView?.syncUI()
        hotkeyView?.syncUI()
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
