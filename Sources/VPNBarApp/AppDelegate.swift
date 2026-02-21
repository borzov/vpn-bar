import AppKit
import os.log

/// Application delegate responsible for initialization and lifecycle management.
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
        registerConnectionHotkeysFromSettings()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionHotkeysDidChange),
            name: .connectionHotkeysDidChange,
            object: nil
        )
    }
    
    @objc @MainActor private func hotkeyDidChange() {
        registerHotkeyFromSettings()
    }

    @objc @MainActor private func connectionHotkeysDidChange() {
        registerConnectionHotkeysFromSettings()
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

    @MainActor
    private func registerConnectionHotkeysFromSettings() {
        let settings = SettingsManager.shared
        HotkeyManager.shared.unregisterAllConnectionHotkeys()

        for hotkey in settings.connectionHotkeys {
            let connectionID = hotkey.connectionID
            HotkeyManager.shared.registerConnectionHotkey(
                connectionID: connectionID,
                keyCode: hotkey.keyCode,
                modifiers: hotkey.modifiers
            ) {
                Task { @MainActor in
                    VPNManager.shared.toggleConnection(connectionID)
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.cleanup()
        Task { @MainActor in
            VPNManager.shared.cleanup()
            NetworkInfoManager.shared.cleanup()
            statusBarController?.cleanup()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

