import Foundation
import Combine

/// Protocol for managing VPN connections.
@MainActor
protocol VPNManagerProtocol: ObservableObject {
    /// List of available connections.
    var connections: [VPNConnection] { get }
    
    /// Flag indicating if there is an active connection.
    var hasActiveConnection: Bool { get }
    
    /// Last error from loading connections list.
    var loadingError: VPNError? { get }
    
    /// Connection status update interval.
    var updateInterval: TimeInterval { get set }
    
    /// Loads or reloads the list of available connections.
    /// - Parameter forceReload: Force reload regardless of cache.
    func loadConnections(forceReload: Bool)
    
    /// Initiates connection to the specified connection.
    /// - Parameters:
    ///   - connectionID: Connection identifier.
    ///   - retryCount: Number of connection attempts (default is 3).
    func connect(to connectionID: String, retryCount: Int)
    
    /// Disconnects the specified connection.
    /// - Parameter connectionID: Connection identifier.
    func disconnect(from connectionID: String)
    
    /// Toggles connection state (connect/disconnect).
    /// - Parameter connectionID: Connection identifier.
    func toggleConnection(_ connectionID: String)

    /// Releases resources when the application terminates.
    func cleanup()
}

