import AppKit
import Combine

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
        // Используем системную тему
        newMenu.appearance = NSApp.effectiveAppearance
        
        // Динамическая часть - VPN подключения
        if vpnManager.connections.isEmpty {
            let noConnectionsItem = NSMenuItem(title: "Нет VPN подключений", action: nil, keyEquivalent: "")
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
                    title += " (подключено)"
                case .connecting:
                    title += " (подключение...)"
                case .disconnecting:
                    title += " (отключение...)"
                case .disconnected:
                    break
                }
                menuItem.title = title
                
                newMenu.addItem(menuItem)
            }
        }
        
        newMenu.addItem(NSMenuItem.separator())
        
        // Статические пункты
        let settingsItem = NSMenuItem(
            title: "Настройки",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        newMenu.addItem(settingsItem)
        
        let quitItem = NSMenuItem(
            title: "Выйти",
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
    
    private func observeConnections() {
        vpnManager.$connections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }
}

