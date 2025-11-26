import AppKit
import Combine
import os.log

class StatusBarController {
    static var shared: StatusBarController?
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager = VPNManager.shared
    
    init() {
        StatusBarController.shared = self
        setupStatusBar()
        observeVPNStatus()
        observeSettingsChanges()
    }
    
    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showConnectionNameDidChange),
            name: .showConnectionNameDidChange,
            object: nil
        )
    }
    
    @objc private func showConnectionNameDidChange() {
        updateTooltip()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        // Устанавливаем начальную иконку
        updateIcon(isActive: vpnManager.hasActiveConnection)
        
        // Обработчик клика
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func observeVPNStatus() {
        vpnManager.$hasActiveConnection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                self?.updateIcon(isActive: isActive)
            }
            .store(in: &cancellables)
        
        // Отслеживаем изменения подключений для обновления tooltip
        vpnManager.$connections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTooltip()
            }
            .store(in: &cancellables)
    }
    
    private func updateIcon(isActive: Bool) {
        guard let button = statusItem?.button else { return }
        
        if isActive {
            // Активное подключение: нормальный цвет + значок со щитом
            let symbolName = "network.badge.shield.half.filled"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                image.isTemplate = true
                button.image = image
                button.contentTintColor = nil
            } else {
                button.title = "🔒"
                button.contentTintColor = nil
            }
        } else {
            // Неактивное подключение: полупрозрачная/серая иконка
            let symbolName = "network"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                image.isTemplate = true
                // Создаем копию изображения с пониженной альфа-каналом
                let grayImage = createGrayedImage(from: image)
                button.image = grayImage
                button.contentTintColor = nil
            } else {
                button.title = "🔓"
                button.contentTintColor = nil
            }
        }
        
        updateTooltip()
    }
    
    private func updateTooltip() {
        guard let button = statusItem?.button else { return }
        
        let isActive = vpnManager.hasActiveConnection
        let settings = SettingsManager.shared
        
        if isActive {
            if settings.showConnectionName {
                if let activeConnection = vpnManager.connections.first(where: { $0.status.isActive }) {
                    button.toolTip = activeConnection.name
                } else {
                    button.toolTip = NSLocalizedString("VPN Connected", comment: "")
                }
            } else {
                button.toolTip = NSLocalizedString("VPN Connected", comment: "")
            }
        } else {
            button.toolTip = NSLocalizedString("VPN Disconnected", comment: "")
        }
    }
    
    private func createGrayedImage(from image: NSImage) -> NSImage {
        let grayImage = NSImage(size: image.size)
        grayImage.lockFocus()
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 0.4)
        grayImage.unlockFocus()
        grayImage.isTemplate = true
        return grayImage
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            MenuController.shared.showMenu(for: statusItem)
        } else if event?.type == .leftMouseUp {
            toggleVPNConnection()
        }
    }
    
    func toggleVPNConnection() {
        let connections = vpnManager.connections
        let wasActive = vpnManager.hasActiveConnection
        var connectionName: String?
        
        if let activeConnection = connections.first(where: { $0.status.isActive }) {
            connectionName = activeConnection.name
            vpnManager.toggleConnection(activeConnection.id)
        } else if let firstConnection = connections.first {
            connectionName = firstConnection.name
            vpnManager.toggleConnection(firstConnection.id)
        }
        
        let settings = SettingsManager.shared
        let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "Notifications")
        
        logger.info("toggleVPNConnection called, showNotifications: \(settings.showNotifications), wasActive: \(wasActive)")
        
        if settings.showNotifications {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else {
                    logger.error("self is nil in notification closure")
                    return
                }
                let isNowActive = self.vpnManager.hasActiveConnection
                logger.info("After delay: isNowActive: \(isNowActive), wasActive: \(wasActive)")
                
                if wasActive != isNowActive {
                    logger.info("Status changed, sending notification")
                    self.notifyStatusChange(isNowActive: isNowActive, connectionName: connectionName)
                } else {
                    logger.info("Status did not change, skipping notification")
                }
            }
        } else {
            logger.info("Notifications disabled in settings")
        }
    }
    
    private func notifyStatusChange(isNowActive: Bool, connectionName: String?) {
        guard SettingsManager.shared.showNotifications else { return }
        
        Task { @MainActor in
            NotificationManager.shared.sendVPNNotification(
                isConnected: isNowActive,
                connectionName: connectionName
            )
        }
    }
    
    func updateMenu() {
        MenuController.shared.updateMenu()
    }
}

