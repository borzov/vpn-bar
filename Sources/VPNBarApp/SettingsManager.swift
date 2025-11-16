import Foundation

class SettingsManager {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let updateIntervalKey = "updateInterval"
    
    private init() {}
    
    // MARK: - Update Interval
    
    var updateInterval: TimeInterval {
        get {
            let saved = userDefaults.double(forKey: updateIntervalKey)
            return saved > 0 ? saved : 10.0 // Значение по умолчанию
        }
        set {
            userDefaults.set(newValue, forKey: updateIntervalKey)
            userDefaults.synchronize()
            NotificationCenter.default.post(name: NSNotification.Name("UpdateIntervalDidChange"), object: nil)
        }
    }
}

