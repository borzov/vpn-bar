import Foundation

/// Protocol for managing network information (IP, geolocation, VPN interfaces).
@MainActor
protocol NetworkInfoManagerProtocol: AnyObject {
    /// Current network info, if available.
    var networkInfo: NetworkInfo? { get }

    /// Refreshes network information.
    /// - Parameter force: If true, ignores cache and fetches fresh data.
    func refresh(force: Bool)

    /// Cleans up resources.
    func cleanup()
}
