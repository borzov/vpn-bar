import Foundation

/// Typed errors for VPN manager.
enum VPNError: LocalizedError, Equatable {
    /// No VPN configurations configured in the system.
    case noConfigurations
    
    /// Connection with specified identifier not found.
    case connectionNotFound(id: String)
    
    /// Session for specified connection not found.
    case sessionNotFound(id: String)
    
    /// Failed to create session for connection.
    case sessionCreationFailed(id: String)
    
    /// Failed to load NetworkExtension framework.
    case frameworkLoadFailed(reason: String)
    
    /// VPN connection error.
    case connectionFailed(underlying: String?)
    
    /// Shared manager unavailable.
    case sharedManagerUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noConfigurations:
            return NSLocalizedString("error.vpn.noConfigurations", comment: "")
        case .connectionNotFound(let id):
            return Self.formatWithFallback(key: "error.vpn.connectionNotFound", param: id)
        case .sessionNotFound(let id):
            return Self.formatWithFallback(key: "error.vpn.sessionNotFound", param: id)
        case .sessionCreationFailed(let id):
            return Self.formatWithFallback(key: "error.vpn.sessionCreateFailed", param: id)
        case .frameworkLoadFailed(let reason):
            return Self.formatWithFallback(key: "error.vpn.loadFrameworkFailed", param: reason)
        case .connectionFailed(let underlying):
            return underlying ?? NSLocalizedString("error.vpn.connectionFailed", comment: "")
        case .sharedManagerUnavailable:
            return NSLocalizedString("error.vpn.sharedManagerUnavailable", comment: "")
        }
    }

    private static func formatWithFallback(key: String, param: String) -> String {
        let fmt = NSLocalizedString(key, comment: "")
        return fmt.contains("%@") ? String(format: fmt, param) : "\(fmt) \(param)"
    }
}

