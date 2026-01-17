import Foundation

/// Запись истории подключения.
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

/// Менеджер истории подключений.
@MainActor
final class ConnectionHistoryManager {
    static let shared = ConnectionHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "connectionHistory"
    private let maxHistoryEntries = 100
    
    private init() {}
    
    /// Получает историю подключений.
    /// - Parameter limit: Максимальное количество записей (по умолчанию 50).
    /// - Returns: Массив записей истории, отсортированных по времени (новые первыми).
    func getHistory(limit: Int = 50) -> [ConnectionHistoryEntry] {
        guard let data = userDefaults.data(forKey: historyKey),
              let entries = try? JSONDecoder().decode([ConnectionHistoryEntry].self, from: data) else {
            return []
        }
        
        return Array(entries.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
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
        
        // Load existing history without sorting (raw data)
        guard let data = userDefaults.data(forKey: historyKey),
              var history = try? JSONDecoder().decode([ConnectionHistoryEntry].self, from: data) else {
            // No existing history, create new with single entry
            if let data = try? JSONEncoder().encode([entry]) {
                userDefaults.set(data, forKey: historyKey)
            }
            return
        }
        
        // Insert new entry at the beginning (most recent)
        history.insert(entry, at: 0)
        
        // Trim to max entries if needed (no sorting required, already in order)
        if history.count > maxHistoryEntries {
            history = Array(history.prefix(maxHistoryEntries))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    /// Очищает историю подключений.
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
    }
}


