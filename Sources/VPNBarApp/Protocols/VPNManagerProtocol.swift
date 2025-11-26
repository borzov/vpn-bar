import Foundation
import Combine

@MainActor
protocol VPNManagerProtocol: ObservableObject {
    var connections: [VPNConnection] { get }
    var hasActiveConnection: Bool { get }
    var loadingError: String? { get }
    var updateInterval: TimeInterval { get set }
    
    func loadConnections(forceReload: Bool)
    func connect(to connectionID: String)
    func disconnect(from connectionID: String)
    func toggleConnection(_ connectionID: String)
    func disconnectAll()
}

