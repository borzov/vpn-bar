import AppKit
import Combine

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager = VPNManager.shared
    
    init() {
        setupStatusBar()
        observeVPNStatus()
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
        
        button.toolTip = isActive ? NSLocalizedString("VPN Connected", comment: "") : NSLocalizedString("VPN Disconnected", comment: "")
    }
    
    private func createGrayedImage(from image: NSImage) -> NSImage {
        let grayImage = NSImage(size: image.size)
        grayImage.lockFocus()
        
        // Рисуем оригинальное изображение с пониженной альфа-каналом
        image.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 0.4)
        
        grayImage.unlockFocus()
        grayImage.isTemplate = true
        return grayImage
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            // Правый клик или Ctrl+клик - открываем меню
            MenuController.shared.showMenu(for: statusItem)
        } else if event?.type == .leftMouseUp {
            // Левый клик - toggle последнего активного или первого подключения
            toggleVPNConnection()
        }
    }
    
    private func toggleVPNConnection() {
        let connections = vpnManager.connections
        
        // Ищем активное подключение
        if let activeConnection = connections.first(where: { $0.status.isActive }) {
            vpnManager.toggleConnection(activeConnection.id)
        } else if let firstConnection = connections.first {
            // Если нет активных, переключаем первое
            vpnManager.toggleConnection(firstConnection.id)
        }
    }
    
    func updateMenu() {
        // Метод для обновления меню извне
        MenuController.shared.updateMenu()
    }
}

