import AppKit
import os.log

/// Делегат приложения, отвечающий за инициализацию и управление жизненным циклом.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AppDelegate")
        logger.info("Application did finish launching")
        
        Task { @MainActor in
            NotificationManager.shared.requestAuthorization()
        }
        
        statusBarController = StatusBarController()
        VPNManager.shared.loadConnections(forceReload: true)
        registerHotkeyFromSettings()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
    }
    
    @objc @MainActor private func hotkeyDidChange() {
        registerHotkeyFromSettings()
    }
    
    @MainActor
    private func registerHotkeyFromSettings() {
        let settings = SettingsManager.shared
        guard let keyCode = settings.hotkeyKeyCode, let modifiers = settings.hotkeyModifiers else { return }
        
        HotkeyManager.shared.registerHotkey(keyCode: keyCode, modifiers: modifiers) {
            Task { @MainActor in
                StatusBarController.shared?.toggleVPNConnection()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.cleanup()
        Task { @MainActor in
            VPNManager.shared.cleanup()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

