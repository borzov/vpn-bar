import Foundation
import Combine
import SystemConfiguration

/// Мониторит статус VPN-подключений.
@MainActor
final class VPNStatusMonitor: VPNStatusMonitorProtocol {
    private let sessionManager: VPNSessionManagerProtocol
    private var updateTimer: Timer?
    private var statusUpdateTimer: Timer?
    private let statusSubject = PassthroughSubject<[String: SCNetworkConnectionStatus], Never>()
    private let statusUpdateInterval: TimeInterval = AppConstants.sessionStatusUpdateInterval
    
    var statusPublisher: AnyPublisher<[String: SCNetworkConnectionStatus], Never> {
        statusSubject.eraseToAnyPublisher()
    }
    
    init(sessionManager: VPNSessionManagerProtocol) {
        self.sessionManager = sessionManager
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllStatuses()
            }
        }
        RunLoop.current.add(statusUpdateTimer!, forMode: .common)
    }
    
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    func refreshStatus(for connectionID: String) {
        sessionManager.getSessionStatus(connectionID: connectionID) { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                var currentStatuses: [String: SCNetworkConnectionStatus] = [:]
                currentStatuses[connectionID] = status
                self.statusSubject.send(currentStatuses)
            }
        }
    }
    
    func refreshAllStatuses() {
        let connectionIDs = sessionManager.allConnectionIDs
        for connectionID in connectionIDs {
            refreshStatus(for: connectionID)
        }
    }
}

