import Foundation

/// Protocol for managing application user settings.
@MainActor
protocol SettingsManagerProtocol {
    /// Connection status update interval in seconds.
    var updateInterval: TimeInterval { get set }
    
    /// Global hotkey key code.
    var hotkeyKeyCode: UInt32? { get set }
    
    /// Global hotkey modifiers.
    var hotkeyModifiers: UInt32? { get set }
    
    /// Flag for showing system notifications.
    var showNotifications: Bool { get set }
    
    /// Flag for showing connection name in tooltip.
    var showConnectionName: Bool { get set }
    
    /// Flag for enabling sound feedback.
    var soundFeedbackEnabled: Bool { get set }
    
    /// Flag for launching application at login.
    var launchAtLogin: Bool { get set }
    
    /// Flag indicating if launch at login is available on current macOS version.
    var isLaunchAtLoginAvailable: Bool { get }
    
    /// Saves hotkey combination.
    /// - Parameters:
    ///   - keyCode: Key code.
    ///   - modifiers: Key modifiers.
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?)
    
    /// Identifier of the last used VPN connection.
    var lastUsedConnectionID: String? { get set }

    /// Per-connection hotkey assignments.
    var connectionHotkeys: [ConnectionHotkey] { get set }

    /// Saves a hotkey for a specific connection.
    func saveConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32)

    /// Removes the hotkey for a specific connection.
    func removeConnectionHotkey(connectionID: String)

    /// Returns the hotkey for a specific connection, if any.
    func connectionHotkey(for connectionID: String) -> ConnectionHotkey?
}

