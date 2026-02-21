import AppKit
import Carbon
import Combine

/// Status bar menu controller.
@MainActor
class MenuController {
    static let shared = MenuController(vpnManager: VPNManager.shared)

    // MARK: - Cached Images

    private var menu: NSMenu?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager: VPNManagerProtocol

    private let networkInfoManager: NetworkInfoManagerProtocol

    init(vpnManager: VPNManagerProtocol, networkInfoManager: NetworkInfoManagerProtocol? = nil) {
        self.vpnManager = vpnManager
        self.networkInfoManager = networkInfoManager ?? NetworkInfoManager.shared
        observeConnections()
    }

    /// Shows menu for the specified status bar item.
    /// - Parameter statusItem: Status bar item for which to build the menu.
    func showMenu(for statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        networkInfoManager.refresh(force: false)
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
    
    /// Creates menu for the specified NSMenu (for testing). Builds directly into the given menu to avoid reusing items across menus.
    func buildMenu(menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(into: menu)
    }

    private func buildMenu() {
        let newMenu = NSMenu()
        if NSApp != nil {
            newMenu.appearance = NSApp.effectiveAppearance
        }
        buildMenu(into: newMenu)
        self.menu = newMenu
    }

    private func buildMenu(into targetMenu: NSMenu) {
        addNetworkInfoSection(to: targetMenu)

        if let error = vpnManager.loadingError {
            let errorItem = NSMenuItem(title: error.errorDescription ?? "", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            errorItem.image = MenuController.errorImage()
            targetMenu.addItem(errorItem)

            let openNetworkPrefsItem = NSMenuItem(
                title: NSLocalizedString(
                    "menu.action.openNetworkPreferences",
                    comment: "Menu action to open macOS Network preferences"
                ),
                action: #selector(openNetworkPreferences(_:)),
                keyEquivalent: ""
            )
            openNetworkPrefsItem.target = self
            targetMenu.addItem(openNetworkPrefsItem)
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
            targetMenu.addItem(noConnectionsItem)
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

                if let hotkey = SettingsManager.shared.connectionHotkey(for: connection.id) {
                    let hotkeyStr = formatHotkeyForMenu(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
                    title += "  \(hotkeyStr)"
                }

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

                targetMenu.addItem(menuItem)
            }
        }

        targetMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.action.settings", comment: "Menu item to open settings"),
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        targetMenu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: NSLocalizedString("menu.action.quit", comment: "Menu item to quit the app"),
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        targetMenu.addItem(quitItem)
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
    
    // MARK: - Network Info

    private func addNetworkInfoSection(to menu: NSMenu) {
        guard vpnManager.hasActiveConnection else { return }

        if let info = networkInfoManager.networkInfo {
            if let location = info.formattedLocation {
                let locationItem = NSMenuItem(title: location, action: nil, keyEquivalent: "")
                locationItem.isEnabled = false
                menu.addItem(locationItem)
            }

            if let ip = info.publicIP {
                let ipTitle = "IP: \(ip)"
                let ipItem = NSMenuItem(
                    title: ipTitle,
                    action: #selector(copyIPAddress(_:)),
                    keyEquivalent: ""
                )
                ipItem.target = self
                ipItem.representedObject = ip
                ipItem.toolTip = NSLocalizedString(
                    "menu.networkInfo.copyIP",
                    comment: "Tooltip for copying IP address"
                )
                menu.addItem(ipItem)
            }

            for iface in info.vpnInterfaces {
                let ifaceTitle = NSLocalizedString(
                    "menu.networkInfo.interface",
                    comment: "VPN interface label"
                ) + ": \(iface.name) (\(iface.address))"
                let ifaceItem = NSMenuItem(title: ifaceTitle, action: nil, keyEquivalent: "")
                ifaceItem.isEnabled = false
                menu.addItem(ifaceItem)
            }
        } else {
            let fetchingItem = NSMenuItem(
                title: NSLocalizedString(
                    "menu.networkInfo.fetching",
                    comment: "Placeholder while loading network info"
                ),
                action: nil,
                keyEquivalent: ""
            )
            fetchingItem.isEnabled = false
            menu.addItem(fetchingItem)
        }

        menu.addItem(NSMenuItem.separator())
    }

    @objc private func copyIPAddress(_ sender: NSMenuItem) {
        guard let ip = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ip, forType: .string)
    }

    // MARK: - Hotkey Formatting

    private func formatHotkeyForMenu(keyCode: UInt32, modifiers: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if let keyStr = KeyCode(rawValue: keyCode)?.stringValue {
            parts.append(keyStr)
        }
        return parts.joined()
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
}
