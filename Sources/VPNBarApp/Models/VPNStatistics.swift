import Foundation

/// VPN usage statistics.
struct VPNStatistics: Codable, Equatable {
    var totalConnections: Int = 0
    var totalDisconnections: Int = 0
    var totalConnectionTime: TimeInterval = 0
    var lastConnectionDate: Date?
    var lastDisconnectionDate: Date?
    var longestSessionDuration: TimeInterval = 0
    var shortestSessionDuration: TimeInterval? = nil
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
    private var cachedStatistics: VPNStatistics

    private func persistStatistics() {
        if let data = try? JSONEncoder().encode(cachedStatistics) {
            userDefaults.set(data, forKey: statisticsKey)
        }
    }

    private init() {
        if let data = userDefaults.data(forKey: statisticsKey),
           let stats = try? JSONDecoder().decode(VPNStatistics.self, from: data) {
            cachedStatistics = stats
        } else {
            cachedStatistics = VPNStatistics()
        }
    }
    
    /// Gets current statistics.
    func getStatistics() -> VPNStatistics {
        return cachedStatistics
    }

    /// Records connection start.
    func recordConnection() {
        currentSessionStart = Date()
        cachedStatistics.totalConnections += 1
        cachedStatistics.lastConnectionDate = Date()
        persistStatistics()
    }

    /// Records connection end.
    func recordDisconnection() {
        guard let start = currentSessionStart else { return }

        let duration = Date().timeIntervalSince(start)
        cachedStatistics.totalDisconnections += 1
        cachedStatistics.totalConnectionTime += duration
        cachedStatistics.lastDisconnectionDate = Date()

        if duration > cachedStatistics.longestSessionDuration {
            cachedStatistics.longestSessionDuration = duration
        }

        if let currentShortest = cachedStatistics.shortestSessionDuration, duration < currentShortest {
            cachedStatistics.shortestSessionDuration = duration
        } else if cachedStatistics.shortestSessionDuration == nil {
            cachedStatistics.shortestSessionDuration = duration
        }

        persistStatistics()
        currentSessionStart = nil
    }

    /// Resets statistics.
    func resetStatistics() {
        cachedStatistics = VPNStatistics()
        persistStatistics()
        currentSessionStart = nil
    }
}


