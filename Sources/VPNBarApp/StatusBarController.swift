import AppKit
import Combine
import os.log

/// Управляет элементом статус-бара и его визуальным состоянием.
@MainActor
class StatusBarController {
    static var shared: StatusBarController?
    
    private var statusItem: NSStatusItem?
    private let viewModel: StatusItemViewModel
    private var lastContent: StatusItemViewModel.ImageContent?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager: VPNManagerProtocol
    private let settingsManager: SettingsManagerProtocol
    
    private var connectingAnimationTimer: Timer?
    private var animationFrame = 0
    
    init(
        vpnManager: VPNManagerProtocol = VPNManager.shared,
        settingsManager: SettingsManagerProtocol = SettingsManager.shared
    ) {
        self.vpnManager = vpnManager
        self.settingsManager = settingsManager
        viewModel = StatusItemViewModel(
            vpnManager: vpnManager,
            settings: settingsManager
        )
        StatusBarController.shared = self
        setupStatusBar()
        bindViewModel()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            button.setAccessibilityLabel(
                NSLocalizedString(
                    "status.accessibility.label",
                    comment: "Accessibility label for the status bar button"
                )
            )
            button.setAccessibilityHelp(
                NSLocalizedString(
                    "status.accessibility.help",
                    comment: "Accessibility help text for the status bar button"
                )
            )
            button.setAccessibilityRole(.button)
        }
    }
    
    private func bindViewModel() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .connecting(let content):
                    self.lastContent = content
                    self.applyTooltip(from: content)
                    self.startConnectingAnimation()
                case .connected(let content):
                    self.stopConnectingAnimation()
                    self.applyContent(content)
                case .disconnected(let content):
                    self.stopConnectingAnimation()
                    self.applyContent(content)
                }
            }
            .store(in: &cancellables)
    }
    
    private func startConnectingAnimation() {
        guard connectingAnimationTimer == nil else { return }
        
        animationFrame = 0
        let timer = Timer.scheduledTimer(withTimeInterval: AppConstants.connectingAnimationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.animateConnectingIcon()
            }
        }
        connectingAnimationTimer = timer
        RunLoop.current.add(timer, forMode: .common)
        
        animateConnectingIcon()
    }
    
    private func stopConnectingAnimation() {
        connectingAnimationTimer?.invalidate()
        connectingAnimationTimer = nil
        animationFrame = 0
        if let content = lastContent {
            applyContent(content)
        }
    }
    
    private func animateConnectingIcon() {
        guard let button = statusItem?.button else { return }
        
        let symbols = [
            "network",
            "network.badge.shield.half.filled"
        ]
        
        let symbolName = symbols[animationFrame % symbols.count]
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
            button.contentTintColor = nil
        } else {
            // Fallback на эмодзи
            button.title = animationFrame % 2 == 0 ? "🔓" : "🔒"
            button.contentTintColor = nil
        }
        
        animationFrame += 1
    }
    
    private func applyContent(_ content: StatusItemViewModel.ImageContent) {
        guard let button = statusItem?.button else { return }
        lastContent = content

        if let image = content.image {
            button.image = image
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.contentTintColor = nil
        }

        applyTooltip(from: content)
    }

    private func applyTooltip(from content: StatusItemViewModel.ImageContent) {
        guard let button = statusItem?.button else { return }
        button.toolTip = content.toolTip
        button.setAccessibilityValue(content.accessibilityValue)
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            MenuController.shared.showMenu(for: statusItem)
        } else if event?.type == .leftMouseUp {
            toggleVPNConnection()
        }
    }
    
    /// Переключает текущее VPN-подключение и при необходимости отправляет уведомление.
    func toggleVPNConnection() {
        let connections = vpnManager.connections
        let wasActive = vpnManager.hasActiveConnection
        var connectionName: String?
        var targetConnectionID: String?
        
        if let lastUsedID = settingsManager.lastUsedConnectionID,
           let lastUsedConnection = connections.first(where: { $0.id == lastUsedID }) {
            targetConnectionID = lastUsedID
            connectionName = lastUsedConnection.name
        } else if let activeConnection = connections.first(where: { $0.status.isActive }) {
            targetConnectionID = activeConnection.id
            connectionName = activeConnection.name
        } else if let firstConnection = connections.first {
            targetConnectionID = firstConnection.id
            connectionName = firstConnection.name
        }
        
        if let connectionID = targetConnectionID {
            vpnManager.toggleConnection(connectionID)
        }
        
        if settingsManager.showNotifications {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                let isNowActive = self.vpnManager.hasActiveConnection
                
                if wasActive != isNowActive {
                    self.notifyStatusChange(isNowActive: isNowActive, connectionName: connectionName)
                }
            }
        }
    }
    
    /// Отправляет системное уведомление об изменении статуса.
    private func notifyStatusChange(isNowActive: Bool, connectionName: String?) {
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
    
    deinit {
        connectingAnimationTimer?.invalidate()
        connectingAnimationTimer = nil
    }

}
