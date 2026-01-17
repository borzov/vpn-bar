import Foundation

/// VPN usage statistics.
struct VPNStatistics: Codable, Equatable {
    var totalConnections: Int = 0
    var totalDisconnections: Int = 0
    var totalConnectionTime: TimeInterval = 0
    var lastConnectionDate: Date?
    var lastDisconnectionDate: Date?
    var longestSessionDuration: TimeInterval = 0
    /// Average session duration in seconds.
    var averageSessionDuration: TimeInterval {
        guard totalConnections > 0 else { return 0 }
        return totalConnectionTime / Double(totalConnections)
    }
}

/// VPN usage statistics manager.
@MainActor
final class StatisticsManager {
    static let shared = StatisticsManager()
    
    private let userDefaults = UserDefaults.standard
    private let statisticsKey = "vpnStatistics"
    private var currentSessionStart: Date?
    private var statistics: VPNStatistics {
        get {
            guard let data = userDefaults.data(forKey: statisticsKey),
                  let stats = try? JSONDecoder().decode(VPNStatistics.self, from: data) else {
                return VPNStatistics()
            }
            return stats
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: statisticsKey)
            }
        }
    }
    
    private init() {}
    
    /// Gets current statistics.
    func getStatistics() -> VPNStatistics {
        return statistics
    }
    
    /// Records connection start.
    func recordConnection() {
        currentSessionStart = Date()
        var stats = statistics
        stats.totalConnections += 1
        stats.lastConnectionDate = Date()
        statistics = stats
    }
    
    /// Records connection end.
    func recordDisconnection() {
        guard let start = currentSessionStart else { return }

        let duration = Date().timeIntervalSince(start)
        var stats = statistics
        stats.totalDisconnections += 1
        stats.totalConnectionTime += duration
        stats.lastDisconnectionDate = Date()

        if duration > stats.longestSessionDuration {
            stats.longestSessionDuration = duration
        }

        if let currentShortest = stats.shortestSessionDuration, duration < currentShortest {
            stats.shortestSessionDuration = duration
        } else if stats.shortestSessionDuration == nil {
            stats.shortestSessionDuration = duration
        }

        statistics = stats
        currentSessionStart = nil
    }
    
    /// Resets statistics.
    func resetStatistics() {
        statistics = VPNStatistics()
        currentSessionStart = nil
    }
}


