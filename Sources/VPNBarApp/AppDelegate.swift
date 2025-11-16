import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Создаем контроллер меню-бара
        statusBarController = StatusBarController()
        
        // Загружаем VPN подключения
        VPNManager.shared.loadConnections()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Очистка при выходе
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Не закрываем приложение при закрытии окна (если оно есть)
        return false
    }
}

