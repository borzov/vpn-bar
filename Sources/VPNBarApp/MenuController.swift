import AppKit
import Combine

/// Контроллер меню статус-бара.
@MainActor
class MenuController {
    static let shared = MenuController()
    
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
        newMenu.appearance = NSApp.effectiveAppearance
        
        if let error = vpnManager.loadingError {
            let errorItem = NSMenuItem(title: error.errorDescription ?? "", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            if let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
                image.isTemplate = true
                errorItem.image = image
            }
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
                    if let image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil) {
                        image.isTemplate = true
                        menuItem.image = image
                    }
                } else {
                    if let image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil) {
                        image.isTemplate = true
                        menuItem.image = image
                    }
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
            if let image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil) {
                image.isTemplate = true
                disconnectAllItem.image = image
            }
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
        
        // Обновляем меню через небольшую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateMenu()
        }
    }
    
    @objc private func showSettings(_ sender: NSMenuItem) {
        SettingsWindowController.shared.showWindow()
    }
    
    @objc private func quitApplication(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func disconnectAllConnections(_ sender: NSMenuItem) {
        vpnManager.disconnectAll()
        
        // Обновляем меню через небольшую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
}
