import AppKit
import Combine

/// Контроллер меню статус-бара.
@MainActor
class MenuController {
    static let shared = MenuController()
    
    // MARK: - Cached Images
    private static var cachedActiveImage: NSImage?
    private static var cachedInactiveImage: NSImage?
    private static var cachedErrorImage: NSImage?
    private static var cachedDisconnectAllImage: NSImage?
    
    private var menu: NSMenu?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager: VPNManagerProtocol
    
    init(vpnManager: VPNManagerProtocol = VPNManager.shared) {
        self.vpnManager = vpnManager
        observeConnections()
    }
    
    /// Показывает меню для указанного элемента статус-бара.
    /// - Parameter statusItem: Элемент статус-бара, для которого строится меню.
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
    
    /// Перестраивает меню с актуальными данными.
    func updateMenu() {
        buildMenu()
    }
    
    /// Создает меню для указанного NSMenu (для тестирования).
    func buildMenu(menu: NSMenu) {
        buildMenu()
        menu.items = self.menu?.items ?? []
    }
    
    private func buildMenu() {
        let newMenu = NSMenu()
        // Set appearance only if NSApplication is available (not in test environment)
        if let app = NSApplication.shared as NSApplication?, app.isRunning {
            newMenu.appearance = app.effectiveAppearance
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
        // Используем VPNManager напрямую для доступа к @Published
        if let vpnManager = vpnManager as? VPNManager {
            vpnManager.$connections
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateMenu()
                }
                .store(in: &cancellables)
        } else {
            // Fallback: обновляем меню один раз
            updateMenu()
        }
    }
    
    // MARK: - Cached Image Helpers
    
    private static func activeImage() -> NSImage? {
        if let cached = cachedActiveImage { return cached }
        guard let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        cachedActiveImage = image
        return image
    }
    
    private static func inactiveImage() -> NSImage? {
        if let cached = cachedInactiveImage { return cached }
        guard let image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        cachedInactiveImage = image
        return image
    }
    
    private static func errorImage() -> NSImage? {
        if let cached = cachedErrorImage { return cached }
        guard let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        cachedErrorImage = image
        return image
    }
    
    private static func disconnectAllImage() -> NSImage? {
        if let cached = cachedDisconnectAllImage { return cached }
        guard let image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) else {
            return nil
        }
        image.isTemplate = true
        cachedDisconnectAllImage = image
        return image
    }
}
