import Foundation

/// Application-wide constants.
enum AppConstants {
    /// Default bundle identifier.
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.borzov.VPNBar"
    
    /// Minimum status update interval in seconds.
    static let minUpdateInterval: TimeInterval = 5.0
    
    /// Maximum status update interval in seconds.
    static let maxUpdateInterval: TimeInterval = 120.0
    
    /// Default status update interval in seconds.
    static let defaultUpdateInterval: TimeInterval = 15.0
    
    /// Session status update interval in seconds.
    static let sessionStatusUpdateInterval: TimeInterval = 5.0
    
    /// VPN connections list reload interval in seconds.
    static let connectionsListReloadInterval: TimeInterval = 30.0
    
    /// Connection animation interval in seconds.
    static let connectingAnimationInterval: TimeInterval = 0.4
    
    /// Default maximum number of connection attempts.
    static let defaultRetryCount: Int = 3
    
    /// Base delay for exponential backoff between attempts in seconds.
    static let retryBaseDelay: TimeInterval = 1.0
    
    /// Timeout for connection/disconnection operations in seconds.
    static let connectionTimeout: TimeInterval = 30.0
    
    /// Delay before sending status change notification in seconds.
    static let notificationDelay: TimeInterval = 0.5
    
    /// Network info cache duration in seconds.
    static let networkInfoCacheDuration: TimeInterval = 30.0

    /// Delay before refreshing network info after VPN status change in seconds.
    static let networkInfoRefreshDelay: TimeInterval = 3.0

    /// Network info related constants.
    enum NetworkInfo {
        static let geoIPURL = URL(string: "https://ipapi.co/json/")!
        static let requestTimeout: TimeInterval = 10.0
    }

    /// URLs used in the application.
    enum URLs {
        static let repository: URL = {
            guard let url = URL(string: "https://github.com/borzov/vpn-bar") else {
                fatalError("Invalid repository URL")
            }
            return url
        }()
        static let networkPreferences: URL = {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") else {
                fatalError("Invalid network preferences URL")
            }
            return url
        }()
    }
}

