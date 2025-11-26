import AppKit
import Combine

@MainActor
class MenuController {
    static let shared = MenuController()
    
    private var menu: NSMenu?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager = VPNManager.shared
    
    private init() {
        observeConnections()
    }
    
    func showMenu(for statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        buildMenu()
        
        guard let statusItem = statusItem,
              let button = statusItem.button else { return }
        
        menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    func updateMenu() {
        buildMenu()
    }
    
    private func buildMenu() {
        let newMenu = NSMenu()
        newMenu.appearance = NSApp.effectiveAppearance
        
        // Показываем ошибку если есть
        if let error = vpnManager.loadingError {
            let errorItem = NSMenuItem(title: error, action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            // Добавляем иконку предупреждения
            if let image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil) {
                image.isTemplate = true
                errorItem.image = image
            }
            newMenu.addItem(errorItem)
            
            // Добавляем кнопку открытия настроек сети
            let openNetworkPrefsItem = NSMenuItem(
                title: NSLocalizedString("Open Network Preferences...", comment: ""),
                action: #selector(openNetworkPreferences(_:)),
                keyEquivalent: ""
            )
            openNetworkPrefsItem.target = self
            newMenu.addItem(openNetworkPrefsItem)
        } else if vpnManager.connections.isEmpty {
            // Динамическая часть - VPN подключения
            let noConnectionsItem = NSMenuItem(title: NSLocalizedString("No VPN Connections", comment: ""), action: nil, keyEquivalent: "")
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
                
                // Добавляем иконку статуса
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
                
                // Обновляем название в зависимости от статуса
                var title = connection.name
                switch connection.status {
                case .connected:
                    title += " (" + NSLocalizedString("Connected", comment: "") + ")"
                case .connecting:
                    title += " (" + NSLocalizedString("Connecting...", comment: "") + ")"
                case .disconnecting:
                    title += " (" + NSLocalizedString("Disconnecting...", comment: "") + ")"
                case .disconnected:
                    break
                }
                menuItem.title = title
                
                // НОВОЕ: Accessibility
                let statusDescription: String
                switch connection.status {
                case .connected:
                    statusDescription = NSLocalizedString("Connected", comment: "")
                case .connecting:
                    statusDescription = NSLocalizedString("Connecting", comment: "")
                case .disconnecting:
                    statusDescription = NSLocalizedString("Disconnecting", comment: "")
                case .disconnected:
                    statusDescription = NSLocalizedString("Disconnected", comment: "")
                }
                
                menuItem.setAccessibilityLabel("\(connection.name), \(statusDescription)")
                menuItem.setAccessibilityHelp(NSLocalizedString("Click to toggle connection", comment: ""))
                
                newMenu.addItem(menuItem)
            }
        }
        
        // НОВОЕ: Добавляем "Disconnect All" если есть активные подключения
        let hasActiveConnections = vpnManager.connections.contains { $0.status.isActive }
        if hasActiveConnections && vpnManager.connections.count > 1 {
            newMenu.addItem(NSMenuItem.separator())
            
            let disconnectAllItem = NSMenuItem(
                title: NSLocalizedString("Disconnect All", comment: ""),
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
        
        // Статические пункты
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("Settings", comment: ""),
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        newMenu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit", comment: ""),
            action: #selector(quitApplication(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        newMenu.addItem(quitItem)
        
        menu = newMenu
    }
    
    @objc private func vpnConnectionToggled(_ sender: NSMenuItem) {
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func observeConnections() {
        vpnManager.$connections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }
}

