import AppKit
import Combine

/// Status bar menu controller.
@MainActor
class MenuController {
    static let shared = MenuController()
    
    // MARK: - Cached Images
    
    private var menu: NSMenu?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager: VPNManagerProtocol
    
    init(vpnManager: VPNManagerProtocol = VPNManager.shared) {
        self.vpnManager = vpnManager
        observeConnections()
    }
    
    /// Shows menu for the specified status bar item.
    /// - Parameter statusItem: Status bar item for which to build the menu.
    func showMenu(for statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        buildMenu()
        
        guard let statusItem = statusItem,
              let button = statusItem.button,
              let window = button.window else { return }
        
        let buttonFrame = button.convert(button.bounds, to: nil)
        let pointInWindow = button.superview?.convert(buttonFrame.origin, to: nil) ?? buttonFrame.origin
        let screenPoint = window.convertPoint(toScreen: NSPoint(x: pointInWindow.x, y: pointInWindow.y + buttonFrame.height))

        menu?.popUp(positioning: nil, at: screenPoint, in: nil)
    }
    
    /// Rebuilds menu with current data.
    func updateMenu() {
        buildMenu()
    }
    
    /// Creates menu for the specified NSMenu (for testing).
    func buildMenu(menu: NSMenu) {
        buildMenu()
        menu.items = self.menu?.items ?? []
    }
    
    private func buildMenu() {
        let newMenu = NSMenu()
        // Set appearance only if NSApplication is available (not in test environment)
        if NSApp != nil {
            newMenu.appearance = NSApp.effectiveAppearance
        }
        
        if let error = vpnManager.loadingError {
            let errorItem = NSMenuItem(title: error.errorDescription ?? "", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            errorItem.image = MenuController.errorImage()
            newMenu.addItem(errorItem)
            
            let openNetworkPrefsItem = NSMenuItem(
                title: NSLocalizedString(
                    "menu.action.openNetworkPreferences",
                    comment: "Menu action to open macOS Network preferences"
                ),
                action: #selector(openNetworkPreferences(_:)),
                keyEquivalent: ""
            )
            openNetworkPrefsItem.target = self
            newMenu.addItem(openNetworkPrefsItem)
        } else if vpnManager.connections.isEmpty {
            let noConnectionsItem = NSMenuItem(
                title: NSLocalizedString(
                    "menu.empty.noConnections",
                    comment: "Shown when there are no VPN configurations"
                ),
                action: nil,
                keyEquivalent: ""
            )
            noConnectionsItem.isEnabled = false
            newMenu.addItem(noConnectionsItem)
        } else {
            for connection in vpnManager.connections {
                let menuItem = NSMenuItem(
                    title: connection.name,
                    action: #selector(vpnConnectionToggled(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = connection.id
                
                if connection.status.isActive {
                    menuItem.image = MenuController.activeImage()
                } else {
                    menuItem.image = MenuController.inactiveImage()
                }
                
                var title = connection.name
                if connection.status != .disconnected {
                    title += " (\(connection.status.localizedDescription))"
                }
                menuItem.title = title
                
                menuItem.setAccessibilityLabel("\(connection.name), \(connection.status.localizedDescription)")
                menuItem.setAccessibilityHelp(
                    NSLocalizedString(
                        "menu.accessibility.toggleConnection",
                        comment: "Accessibility help for toggling a VPN connection from menu"
                    )
                )
                
                newMenu.addItem(menuItem)
            }
        }
        
        let hasActiveConnections = vpnManager.connections.contains { $0.status.isActive }
        if hasActiveConnections && vpnManager.connections.count > 1 {
            newMenu.addItem(NSMenuItem.separator())
            
            let disconnectAllItem = NSMenuItem(
                title: NSLocalizedString(
                    "menu.action.disconnectAll",
                    comment: "Menu action to disconnect all VPN connections"
                ),
                action: #selector(disconnectAllConnections(_:)),
                keyEquivalent: ""
            )
            disconnectAllItem.target = self
            disconnectAllItem.image = MenuController.disconnectAllImage()
            newMenu.addItem(disconnectAllItem)
        }
        
        newMenu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.action.settings", comment: "Menu item to open settings"),
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        newMenu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(
            title: NSLocalizedString("menu.action.quit", comment: "Menu item to quit the app"),
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        newMenu.addItem(quitItem)
        
        menu = newMenu
    }
    
    @objc func vpnConnectionToggled(_ sender: NSMenuItem) {
        guard let connectionID = sender.representedObject as? String else { return }
        vpnManager.toggleConnection(connectionID)
        scheduleMenuUpdate()
    }
    
    @objc private func showSettings(_ sender: NSMenuItem) {
        SettingsWindowController.shared.showWindow()
    }
    
    @objc private func quitApplication(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func disconnectAllConnections(_ sender: NSMenuItem) {
        vpnManager.disconnectAll()
        scheduleMenuUpdate()
    }
    
    private func scheduleMenuUpdate() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.notificationDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.updateMenu()
        }
    }
    
    @objc private func openNetworkPreferences(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(AppConstants.URLs.networkPreferences)
    }
    
    private func observeConnections() {
        if let vpnManager = vpnManager as? VPNManager {
            vpnManager.$connections
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateMenu()
                }
                .store(in: &cancellables)
        } else {
            updateMenu()
        }
    }
    
    // MARK: - Cached Image Helpers
    
    private static func activeImage() -> NSImage? {
        return ImageCache.shared.image(systemSymbolName: "checkmark.circle.fill")
    }
    
    private static func inactiveImage() -> NSImage? {
        return ImageCache.shared.image(systemSymbolName: "circle")
    }
    
    private static func errorImage() -> NSImage? {
        return ImageCache.shared.image(systemSymbolName: "exclamationmark.triangle")
    }
    
    private static func disconnectAllImage() -> NSImage? {
        return ImageCache.shared.image(systemSymbolName: "xmark.circle")
    }
}
