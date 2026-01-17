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
    
    /// Explicitly cleans up all resources. Should be called when the application terminates.
    func cleanup()
}


