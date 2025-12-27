import Foundation
import SystemConfiguration
import os.log

/// Управляет VPN-сессиями.
@MainActor
final class VPNSessionManager: VPNSessionManagerProtocol {
    private var sessions: [String: ne_session_t] = [:]
    private let sessionQueue = DispatchQueue(label: "VPNBarApp.sessionQueue")
    private var sessionStatuses: [String: SCNetworkConnectionStatus] = [:]
    private var statusUpdateHandler: ((String, SCNetworkConnectionStatus) -> Void)?
    
    init(statusUpdateHandler: ((String, SCNetworkConnectionStatus) -> Void)? = nil) {
        self.statusUpdateHandler = statusUpdateHandler
    }
    
    func getOrCreateSession(for uuid: NSUUID) async {
        let identifier = uuid.uuidString
        
        guard sessions[identifier] == nil else { return }
        
        let session = await withCheckedContinuation { continuation in
            sessionQueue.async {
                var uuidBytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
                uuid.getBytes(&uuidBytes)
                
                let session = withUnsafePointer(to: &uuidBytes) { uuidPtr in
                    ne_session_create(uuidPtr, NESessionTypeVPN) as ne_session_t?
                }
                
                continuation.resume(returning: session)
            }
        }
        
        guard let session = session else {
            Logger.vpn.error("Session creation failed for identifier: \(identifier)")
            return
        }
        
        if sessions[identifier] == nil {
            sessions[identifier] = session
            
            ne_session_set_event_handler(session, sessionQueue) { [weak self] event, _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.refreshSessionStatus(for: identifier, session: session)
                }
            }
            
            refreshSessionStatus(for: identifier, session: session)
        } else {
            ne_session_release(session)
        }
    }
    
    func startConnection(connectionID: String) throws {
        guard let session = sessions[connectionID] else {
            throw VPNError.sessionNotFound(id: connectionID)
        }
        
        ne_session_set_event_handler(session, sessionQueue) { [weak self] event, eventData in
            Task { @MainActor in
                guard let self = self else { return }
                
                switch event {
                case 1: // Connected
                    Logger.vpn.info("Connection established: \(connectionID)")
                    self.refreshSessionStatus(for: connectionID, session: session)
                case 2: // Failed
                    Logger.vpn.error("Connection failed: \(connectionID)")
                    self.refreshSessionStatus(for: connectionID, session: session)
                default:
                    self.refreshSessionStatus(for: connectionID, session: session)
                }
            }
        }
        
        ne_session_start(session)
    }
    
    func stopConnection(connectionID: String) throws {
        guard let session = sessions[connectionID] else {
            throw VPNError.sessionNotFound(id: connectionID)
        }
        
        ne_session_stop(session)
    }
    
    func getSessionStatus(connectionID: String, completion: @escaping (SCNetworkConnectionStatus) -> Void) {
        guard let session = sessions[connectionID] else {
            completion(.invalid)
            return
        }
        
        refreshSessionStatus(for: connectionID, session: session, completion: completion)
    }
    
    func getCachedStatus(for connectionID: String) -> SCNetworkConnectionStatus {
        return sessionStatuses[connectionID] ?? .invalid
    }
    
    func hasSession(for connectionID: String) -> Bool {
        return sessions[connectionID] != nil
    }
    
    var allConnectionIDs: [String] {
        return Array(sessions.keys)
    }
    
    func cleanup() {
        for (_, session) in sessions {
            ne_session_cancel(session)
            ne_session_release(session)
        }
        sessions.removeAll()
        sessionStatuses.removeAll()
    }
    
    private func refreshSessionStatus(for identifier: String, session: ne_session_t, completion: ((SCNetworkConnectionStatus) -> Void)? = nil) {
        ne_session_get_status(session, sessionQueue) { [weak self] status in
            Task { @MainActor in
                guard let self = self else { return }
                let scStatus = SCNetworkConnectionGetStatusFromNEStatus(status)
                let oldStatus = self.sessionStatuses[identifier]
                self.sessionStatuses[identifier] = scStatus
                
                if oldStatus != scStatus {
                    self.statusUpdateHandler?(identifier, scStatus)
                }
                
                completion?(scStatus)
            }
        }
    }
}

