import Foundation

/// Hotkey assignment for a specific VPN connection.
struct ConnectionHotkey: Codable, Equatable, Identifiable {
    let connectionID: String
    let keyCode: UInt32
    let modifiers: UInt32
    var id: String { connectionID }
}
