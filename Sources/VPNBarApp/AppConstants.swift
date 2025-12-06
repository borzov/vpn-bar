import Foundation

/// Общие константы приложения.
enum AppConstants {
    /// Идентификатор bundle по умолчанию.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.borzov.VPNBar"
    
    /// Отображаемое имя приложения.
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "VPN Bar"
    
    /// Версия приложения из `CFBundleShortVersionString`.
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    
    /// Номер сборки из `CFBundleVersion`.
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    
    /// Минимальный интервал обновления статуса в секундах.
    static let minUpdateInterval: TimeInterval = 5.0
    
    /// Максимальный интервал обновления статуса в секундах.
    static let maxUpdateInterval: TimeInterval = 120.0
    
    /// Интервал обновления статуса по умолчанию в секундах.
    static let defaultUpdateInterval: TimeInterval = 15.0
    
    /// Интервал обновления статуса сессий в секундах.
    static let sessionStatusUpdateInterval: TimeInterval = 5.0
}

