import Foundation

/// Protocol for loading VPN configurations from the system.
@MainActor
protocol VPNConfigurationLoaderProtocol {
    /// Loads available VPN configurations.
    /// - Parameter completion: Result handler.
    func loadConfigurations(completion: @escaping (Result<[VPNConnection], VPNError>) -> Void)
}


