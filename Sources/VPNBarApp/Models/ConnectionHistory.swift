import Foundation

/// Connection history entry.
struct ConnectionHistoryEntry: Codable, Identifiable {
    let id: String
    let connectionID: String
    let connectionName: String
    let timestamp: Date
    let action: Action
    
    enum Action: String, Codable {
        case connected
        case disconnected
    }
}

/// Connection history manager.
@MainActor
final class ConnectionHistoryManager {
    static let shared = ConnectionHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "connectionHistory"
    private let maxHistoryEntries = 100
    
    /// In-memory cache to avoid frequent UserDefaults I/O.
    private var cachedHistory: [ConnectionHistoryEntry]?
    private var isDirty = false
    
    private init() {
        loadHistoryFromUserDefaults()
    }
    
    /// Loads history from UserDefaults into cache.
    private func loadHistoryFromUserDefaults() {
        guard let data = userDefaults.data(forKey: historyKey),
              let entries = try? JSONDecoder().decode([ConnectionHistoryEntry].self, from: data) else {
            cachedHistory = []
            return
        }
        cachedHistory = entries.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Saves history from cache to UserDefaults.
    private func saveHistoryToUserDefaults() {
        guard isDirty, let history = cachedHistory else { return }
        
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
            isDirty = false
        }
    }
    
    /// Gets connection history.
    /// - Parameter limit: Maximum number of entries (default is 50).
    /// - Returns: Array of history entries sorted by time (newest first).
    func getHistory(limit: Int = 50) -> [ConnectionHistoryEntry] {
        // Ensure cache is loaded
        if cachedHistory == nil {
            loadHistoryFromUserDefaults()
        }
        
        guard let history = cachedHistory else {
            return []
        }
        
        return Array(history.prefix(limit))
    }
    
    /// Adds entry to connection history.
    /// - Parameters:
    ///   - connectionID: Connection identifier.
    ///   - connectionName: Connection name.
    ///   - action: Action (connected/disconnected).
    func addEntry(connectionID: String, connectionName: String, action: ConnectionHistoryEntry.Action) {
        let entry = ConnectionHistoryEntry(
            id: UUID().uuidString,
            connectionID: connectionID,
            connectionName: connectionName,
            timestamp: Date(),
            action: action
        )
        
        // Ensure cache is loaded
        if cachedHistory == nil {
            loadHistoryFromUserDefaults()
        }
        
        var history = cachedHistory ?? []
        
        // Insert new entry at the beginning (most recent)
        history.insert(entry, at: 0)
        
        // Trim to max entries if needed
        if history.count > maxHistoryEntries {
            history = Array(history.prefix(maxHistoryEntries))
        }
        
        cachedHistory = history
        isDirty = true
        
        // Save immediately for data persistence
        saveHistoryToUserDefaults()
    }
    
    /// Clears connection history.
    func clearHistory() {
        cachedHistory = []
        isDirty = true
        userDefaults.removeObject(forKey: historyKey)
    }
}


