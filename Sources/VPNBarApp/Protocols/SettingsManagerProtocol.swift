import Foundation

/// Интерфейс управления пользовательскими настройками приложения.
@MainActor
protocol SettingsManagerProtocol {
    /// Интервал обновления статуса соединений в секундах.
    var updateInterval: TimeInterval { get set }
    
    /// Код клавиши глобального хоткея.
    var hotkeyKeyCode: UInt32? { get set }
    
    /// Модификаторы для глобального хоткея.
    var hotkeyModifiers: UInt32? { get set }
    
    /// Флаг отображения системных уведомлений.
    var showNotifications: Bool { get set }
    
    /// Флаг показа имени подключения в тултипе.
    var showConnectionName: Bool { get set }
    
    /// Признак автозапуска приложения при входе в систему.
    var launchAtLogin: Bool { get set }
    
    /// Признак доступности функции автозапуска на текущей версии macOS.
    var isLaunchAtLoginAvailable: Bool { get }
    
    /// Сохраняет комбинацию горячей клавиши.
    /// - Parameters:
    ///   - keyCode: Код клавиши.
    ///   - modifiers: Модификаторы клавиш.
    func saveHotkey(keyCode: UInt32?, modifiers: UInt32?)
}

