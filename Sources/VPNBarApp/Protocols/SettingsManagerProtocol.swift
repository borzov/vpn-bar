import Foundation

@MainActor
protocol SettingsManagerProtocol {
    var updateInterval: TimeInterval { get set }
    var hotkeyKeyCode: UInt32? { get set }
    var hotkeyModifiers: UInt32? { get set }
    var showNotifications: Bool { get set }
    var showConnectionName: Bool { get set }
    var launchAtLogin: Bool { get set }
    var isLaunchAtLoginAvailable: Bool { get }
    
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?)
}

