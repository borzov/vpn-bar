import Foundation

/// Protocol for managing hotkeys.
protocol HotkeyManagerProtocol {
    /// Registers a global hotkey.
    /// - Parameters:
    ///   - keyCode: Key code.
    ///   - modifiers: Carbon modifiers.
    ///   - callback: Press handler.
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void)
    
    /// Unregisters the hotkey and clears the callback.
    func unregisterHotkey()
    
    /// Registers a hotkey for a specific connection.
    func registerConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void)

    /// Unregisters the hotkey for a specific connection.
    func unregisterConnectionHotkey(connectionID: String)

    /// Unregisters all per-connection hotkeys.
    func unregisterAllConnectionHotkeys()

    /// Explicitly cleans up all resources. Should be called when the application terminates.
    func cleanup()
}
