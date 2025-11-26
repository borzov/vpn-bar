import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "AppDelegate")
        logger.info("Application did finish launching")
        
        // Запрашиваем разрешение на уведомления
        Task { @MainActor in
            NotificationManager.shared.requestAuthorization()
        }
        
        // Создаем контроллер меню-бара
        statusBarController = StatusBarController()
        
        // Загружаем VPN подключения
        VPNManager.shared.loadConnections()
        
        // Регистрируем горячие клавиши из настроек
        registerHotkeyFromSettings()
        
        // Подписываемся на изменения горячих клавиш
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
        if let keyCode = settings.hotkeyKeyCode, let modifiers = settings.hotkeyModifiers {
            HotkeyManager.shared.registerHotkey(keyCode: keyCode, modifiers: modifiers) {
                Task { @MainActor in
                    StatusBarController.shared?.toggleVPNConnection()
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

