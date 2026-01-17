import Foundation
import SystemConfiguration
import os.log

/// Manages VPN sessions with thread-safe access using actor isolation.
actor VPNSessionManager: VPNSessionManagerProtocol {
    private var sessions: [String: ne_session_t] = [:]
    private let sessionQueue = DispatchQueue(label: "VPNBarApp.sessionQueue")
    private var sessionStatuses: [String: SCNetworkConnectionStatus] = [:]
    private var statusUpdateHandler: (@Sendable (String, SCNetworkConnectionStatus) -> Void)?
    
    init(statusUpdateHandler: (@Sendable (String, SCNetworkConnectionStatus) -> Void)? = nil) {
        self.statusUpdateHandler = statusUpdateHandler
    }
    
    func getOrCreateSession(for uuid: NSUUID) async {
        let identifier = uuid.uuidString
        
        // Thread-safe check: actor isolation guarantees no race condition
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
        
        // Store session immediately after creation (no race condition due to actor)
        sessions[identifier] = session
        
        // Set event handler with weak self to prevent retain cycle
        ne_session_set_event_handler(session, sessionQueue) { [weak self] event, _ in
            Task {
                guard let self = self else { return }
                
                // Log significant connection events
                switch event {
                case 1: // NESessionEventTypeConnected
                    Logger.vpn.info("Connection established: \(identifier)")
                case 2: // NESessionEventTypeFailed
                    Logger.vpn.error("Connection failed: \(identifier)")
                default:
                    break
                }
                
                await self.refreshSessionStatus(for: identifier, session: session)
            }
        }
        
        await refreshSessionStatus(for: identifier, session: session)
    }
    
    func startConnection(connectionID: String) throws {
        guard let session = sessions[connectionID] else {
            throw VPNError.sessionNotFound(id: connectionID)
        }

        // Event handler is already set in getOrCreateSession(), no need to set again
        // This prevents multiple handlers firing simultaneously and memory leaks

        ne_session_start(session)
    }
    
    func stopConnection(connectionID: String) throws {
        guard let session = sessions[connectionID] else {
            throw VPNError.sessionNotFound(id: connectionID)
        }
        
        ne_session_stop(session)
    }
    
    func getSessionStatus(connectionID: String, completion: @escaping @Sendable (SCNetworkConnectionStatus) -> Void) async {
        guard let session = sessions[connectionID] else {
            completion(.invalid)
            return
        }
        
        await refreshSessionStatus(for: connectionID, session: session, completion: completion)
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
    
    private func refreshSessionStatus(for identifier: String, session: ne_session_t, completion: (@Sendable (SCNetworkConnectionStatus) -> Void)? = nil) async {
        await withCheckedContinuation { continuation in
            ne_session_get_status(session, sessionQueue) { [weak self] status in
                Task {
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    let scStatus = SCNetworkConnectionGetStatusFromNEStatus(status)
                    let oldStatus = await self.sessionStatuses[identifier]
                    await self.updateStatus(identifier: identifier, status: scStatus)
                    
                    if oldStatus != scStatus {
                        await self.notifyStatusChange(identifier: identifier, status: scStatus)
                    }
                    
                    completion?(scStatus)
                    continuation.resume()
                }
            }
        }
    }
    
    private func updateStatus(identifier: String, status: SCNetworkConnectionStatus) {
        sessionStatuses[identifier] = status
    }
    
    private func notifyStatusChange(identifier: String, status: SCNetworkConnectionStatus) {
        statusUpdateHandler?(identifier, status)
    }
}

