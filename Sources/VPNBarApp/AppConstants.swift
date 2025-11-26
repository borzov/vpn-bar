import Foundation

enum AppConstants {
    /// Bundle identifier приложения
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.borzov.VPNBar"
    
    /// Название приложения для отображения
    static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "VPN Bar"
    
    /// Версия приложения
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    
    /// Номер сборки
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    
    /// Минимальный интервал обновления статуса (секунды)
    static let minUpdateInterval: TimeInterval = 5.0
    
    /// Максимальный интервал обновления статуса (секунды)
    static let maxUpdateInterval: TimeInterval = 120.0
    
    /// Интервал обновления статуса по умолчанию (секунды)
    static let defaultUpdateInterval: TimeInterval = 15.0
    
    /// Интервал обновления статуса сессий (секунды)
    static let sessionStatusUpdateInterval: TimeInterval = 5.0
}

