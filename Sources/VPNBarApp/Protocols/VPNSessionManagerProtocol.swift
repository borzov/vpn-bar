import Foundation
import SystemConfiguration

/// Protocol for managing VPN sessions with thread-safe operations.
protocol VPNSessionManagerProtocol: Actor {
    /// Gets or creates a session for the specified UUID.
    /// - Parameter uuid: Connection UUID.
    func getOrCreateSession(for uuid: NSUUID) async
    
    /// Starts connection for the specified identifier.
    /// - Parameter connectionID: Connection identifier.
    func startConnection(connectionID: String) throws
    
    /// Stops connection for the specified identifier.
    /// - Parameter connectionID: Connection identifier.
    func stopConnection(connectionID: String) throws
    
    /// Gets session status asynchronously.
    /// - Parameters:
    ///   - connectionID: Connection identifier.
    ///   - completion: Result handler.
    func getSessionStatus(connectionID: String, completion: @escaping @Sendable (SCNetworkConnectionStatus) -> Void) async
    
    /// Checks if session exists for the specified connection.
    /// - Parameter connectionID: Connection identifier.
    /// - Returns: `true` if session exists, otherwise `false`.
    func hasSession(for connectionID: String) -> Bool
    
    /// Gets cached status for the specified connection.
    /// - Parameter connectionID: Connection identifier.
    /// - Returns: Cached connection status.
    func getCachedStatus(for connectionID: String) -> SCNetworkConnectionStatus
    
    /// Returns list of all connection identifiers that have sessions.
    var allConnectionIDs: [String] { get }
    
    /// Releases all session resources on application termination.
    func cleanup()
}

