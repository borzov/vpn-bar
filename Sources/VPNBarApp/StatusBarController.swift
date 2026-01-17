import AppKit
import Combine
import os.log

/// Manages status bar item and its visual state.
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
    
    /// Toggles current VPN connection and sends notification if needed.
    func toggleVPNConnection() {
        let connections = vpnManager.connections
        
        // Early return if no connections available
        guard !connections.isEmpty else {
            Logger.vpn.warning("No VPN connections available to toggle")
            return
        }
        
        let wasActive = vpnManager.hasActiveConnection
        var connectionName: String?
        var targetConnectionID: String?
        
        // Determine target connection in priority order
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
        
        guard let connectionID = targetConnectionID else {
            Logger.vpn.error("Failed to determine target connection ID")
            return
        }
        
        vpnManager.toggleConnection(connectionID)
        
        if settingsManager.showNotifications {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.notificationDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                
                let isNowActive = self.vpnManager.hasActiveConnection
                if wasActive != isNowActive {
                    self.notifyStatusChange(isNowActive: isNowActive, connectionName: connectionName)
                }
            }
        }
    }
    
    /// Sends system notification about status change.
    private func notifyStatusChange(isNowActive: Bool, connectionName: String?) {
        Task { @MainActor in
            NotificationManager.shared.sendVPNNotification(
                isConnected: isNowActive,
                connectionName: connectionName
            )
        }
    }
    
    deinit {
        connectingAnimationTimer?.invalidate()
        connectingAnimationTimer = nil
    }

}
