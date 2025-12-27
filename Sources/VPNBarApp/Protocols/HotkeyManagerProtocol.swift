import Foundation

/// Интерфейс менеджера горячих клавиш.
protocol HotkeyManagerProtocol {
    /// Регистрирует глобальную горячую клавишу.
    /// - Parameters:
    ///   - keyCode: Код клавиши.
    ///   - modifiers: Модификаторы Carbon.
    ///   - callback: Обработчик нажатия.
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void)
    
    /// Отменяет регистрацию горячей клавиши и очищает callback.
    func unregisterHotkey()
    
    /// Явно очищает все ресурсы. Должен вызываться при завершении приложения.
    func cleanup()
}


