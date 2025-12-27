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
    
    /// Добавляет запись в историю.
    /// - Parameters:
    ///   - connectionID: Идентификатор соединения.
    ///   - connectionName: Имя соединения.
    ///   - action: Действие (подключение/отключение).
    func addEntry(connectionID: String, connectionName: String, action: ConnectionHistoryEntry.Action) {
        let entry = ConnectionHistoryEntry(
            id: UUID().uuidString,
            connectionID: connectionID,
            connectionName: connectionName,
            timestamp: Date(),
            action: action
        )
        
        var history = getHistory(limit: maxHistoryEntries)
        history.append(entry)
        
        if history.count > maxHistoryEntries {
            history = Array(history.sorted { $0.timestamp > $1.timestamp }.prefix(maxHistoryEntries))
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


