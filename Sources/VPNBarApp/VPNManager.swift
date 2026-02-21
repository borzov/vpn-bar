import Foundation
import SystemConfiguration
import Darwin
import os.log

/// Manages VPN connections, responsible for loading configurations and managing sessions.
@MainActor
class VPNManager: VPNManagerProtocol {
    static let shared: VPNManager = {
        // Create session manager with notification-based status updates to avoid recursion
        let statusHandler: @Sendable (String, SCNetworkConnectionStatus) -> Void = { connectionID, status in
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .vpnConnectionStatusDidUpdate,
                    object: nil,
                    userInfo: [
                        "connectionID": connectionID,
                        "status": status
                    ]
                )
            }
        }

        let sessionManager = VPNSessionManager(statusUpdateHandler: statusHandler)

        let manager = VPNManager(
            configurationLoader: VPNConfigurationLoader(),
            sessionManager: sessionManager
        )

        return manager
    }()
    
    @Published var connections: [VPNConnection] = []
    @Published var hasActiveConnection: Bool = false
    @Published var loadingError: VPNError?
    
    private let configurationLoader: VPNConfigurationLoaderProtocol
    private var sessionManager: any VPNSessionManagerProtocol
    private var updateTimer: Timer?
    private var loadTask: Task<Void, Never>?
    /// Request ID for tracking the relevance of configuration load results.
    /// Used to prevent race conditions: stale results are ignored if a new load request
    /// was initiated during their processing.
    /// Uses overflow-safe operator `&+=` - wraparound is not a practical concern.
    private var loadRequestID: UInt64 = 0
    /// Dictionary of timeout tasks for disconnection operations by connectionID.
    /// Each task tracks the disconnection timeout and resets the connection status
    /// if disconnection doesn't complete within the specified time.
    /// Tasks are automatically cancelled upon successful disconnection.
    private var disconnectTimeoutTasks: [String: Task<Void, Never>] = [:]
    /// Connection ID to connect after all active connections are fully disconnected.
    private var pendingConnectionID: String?
    /// Token for the status update notification observer.
    private var statusObserverToken: NSObjectProtocol?
    
    /// Update interval for the connections list; restarts monitoring when changed.
    var updateInterval: TimeInterval {
        get {
            SettingsManager.shared.updateInterval
        }
        set {
            SettingsManager.shared.updateInterval = newValue
            restartMonitoring()
        }
    }
    
    private var lastStatusUpdate: Date = Date()
    private var lastFullReload: Date = Date()
    private let statusUpdateInterval: TimeInterval = AppConstants.sessionStatusUpdateInterval
    private let connectionsListReloadInterval: TimeInterval = AppConstants.connectionsListReloadInterval
    
    init(
        configurationLoader: VPNConfigurationLoaderProtocol? = nil,
        sessionManager: (any VPNSessionManagerProtocol)? = nil
    ) {
        self.configurationLoader = configurationLoader ?? VPNConfigurationLoader()
        
        if let manager = sessionManager {
            self.sessionManager = manager
        } else {
            // Create default session manager if not provided
            let statusHandler: @Sendable (String, SCNetworkConnectionStatus) -> Void = { connectionID, status in
                Task { @MainActor in
                    NotificationCenter.default.post(
                        name: .vpnConnectionStatusDidUpdate,
                        object: nil,
                        userInfo: [
                            "connectionID": connectionID,
                            "status": status
                        ]
                    )
                }
            }
            self.sessionManager = VPNSessionManager(statusUpdateHandler: statusHandler)
        }

        // Always subscribe to status updates.
        // For shared instance: VPNSessionManager posts them via statusHandler.
        // For tests with MockVPNSessionManager: mock doesn't post notifications, observer won't fire.
        self.statusObserverToken = NotificationCenter.default.addObserver(
            forName: .vpnConnectionStatusDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let connectionID = notification.userInfo?["connectionID"] as? String,
                  let status = notification.userInfo?["status"] as? SCNetworkConnectionStatus else {
                return
            }
            Task { @MainActor in
                self.handleStatusUpdate(connectionID: connectionID, scStatus: status)
            }
        }
        
        loadConnections(forceReload: true)
        lastFullReload = Date()
        startMonitoring()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        if let token = statusObserverToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    /// Loads available VPN configurations.
    /// - Parameter forceReload: Forces reload even if cache is available.
    /// 
    /// Uses request versioning (loadRequestID) to prevent race conditions:
    /// if a new request was initiated during result processing, the old result is ignored.
    func loadConnections(forceReload: Bool = false) {
        loadTask?.cancel()

        if forceReload {
            lastFullReload = Date()
        }

        // Increment request ID to track this specific load request
        // Uses overflow-safe operator &+= - wraparound is not a practical concern
        loadRequestID &+= 1
        let currentRequestID = loadRequestID

        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            loadingError = nil

            configurationLoader.loadConfigurations { [weak self] result in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Check if this is still the latest request
                    // This prevents stale results from overwriting newer ones
                    guard currentRequestID == self.loadRequestID else {
                        Logger.vpn.debug("Ignoring stale load result (request \(currentRequestID), current \(self.loadRequestID))")
                        return
                    }

                    switch result {
                    case .success(let loadedConnections):
                        self.processLoadedConnections(loadedConnections)

                        let now = Date()
                        if now.timeIntervalSince(self.lastStatusUpdate) >= self.statusUpdateInterval {
                            self.lastStatusUpdate = now
                            self.refreshAllStatuses()
                        }
                    case .failure(let error):
                        self.handleLoadError(error)
                    }
                }
            }
        }
    }
    
    /// Connects to the selected connection.
    /// - Parameters:
    ///   - connectionID: Connection identifier.
    ///   - retryCount: Number of connection attempts (default is 3).
    func connect(to connectionID: String, retryCount: Int = AppConstants.defaultRetryCount) {
        connectWithRetry(to: connectionID, retryCount: retryCount, attempt: 1)
    }
    
    private func connectWithRetry(to connectionID: String, retryCount: Int, attempt: Int) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            loadingError = .connectionNotFound(id: connectionID)
            Logger.vpn.error("Connection not found: \(connectionID)")
            return
        }

        Task { @MainActor in
            let hasSession = await sessionManager.hasSession(for: connectionID)
            
            if hasSession {
                await attemptConnection(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
            } else {
                await createSessionAndConnect(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
            }
        }
    }
    
    /// Attempts to start connection when session already exists.
    private func attemptConnection(connectionID: String, retryCount: Int, attempt: Int) async {
        do {
            try await sessionManager.startConnection(connectionID: connectionID)
            handleConnectionSuccess(connectionID: connectionID)
        } catch {
            Logger.vpn.error("Failed to start connection: \(error.localizedDescription)")
            if attempt < retryCount {
                await scheduleRetry(connectionID: connectionID, retryCount: retryCount, attempt: attempt, error: error)
            } else {
                handleConnectionError(connectionID: connectionID, error: error)
            }
        }
    }
    
    /// Creates session and attempts connection.
    private func createSessionAndConnect(connectionID: String, retryCount: Int, attempt: Int) async {
        guard let uuid = UUID(uuidString: connectionID) else {
            loadingError = .sessionNotFound(id: connectionID)
            Logger.vpn.error("Invalid UUID for connection: \(connectionID)")
            resetConnectionToDisconnected(connectionID: connectionID)
            return
        }
        
        let nsUUID = uuid as NSUUID
        await sessionManager.getOrCreateSession(for: nsUUID)
        
        let hasSessionNow = await sessionManager.hasSession(for: connectionID)
        guard hasSessionNow else {
            handleConnectionFailure(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
            return
        }
        
        do {
            try await sessionManager.startConnection(connectionID: connectionID)
            handleConnectionSuccess(connectionID: connectionID)
        } catch {
            handleConnectionFailure(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
        }
    }
    
    /// Handles successful connection start.
    private func handleConnectionSuccess(connectionID: String) {
        updateConnectionToConnecting(connectionID: connectionID)
    }
    
    /// Schedules retry with exponential backoff.
    private func scheduleRetry(connectionID: String, retryCount: Int, attempt: Int, error: Error) async {
        let delay = AppConstants.retryBaseDelay * pow(2.0, Double(attempt - 1))
        Logger.vpn.info("Connection failed, retrying in \(delay) seconds... (attempt \(attempt)/\(retryCount))")
        
        do {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            connectWithRetry(to: connectionID, retryCount: retryCount, attempt: attempt + 1)
        } catch {
            // Task was cancelled
            return
        }
    }
    
    /// Handles connection error when all retries are exhausted.
    private func handleConnectionError(connectionID: String, error: Error) {
        loadingError = error as? VPNError ?? .connectionFailed(underlying: error.localizedDescription)
        resetConnectionToDisconnected(connectionID: connectionID)
    }
    
    /// Sets connection status if it differs from current status.
    /// - Parameters:
    ///   - id: Connection identifier.
    ///   - status: New status to set.
    private func setConnectionStatus(id: String, status: VPNConnection.VPNStatus) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        guard connections[index].status != status else { return }
        
        var updatedConnections = connections
        updatedConnections[index].status = status
        connections = updatedConnections
        updateActiveStatus()
    }
    
    private func updateConnectionToConnecting(connectionID: String) {
        setConnectionStatus(id: connectionID, status: .connecting)
    }
    
    
    private func handleConnectionFailure(connectionID: String, retryCount: Int, attempt: Int) {
        if attempt < retryCount {
            let delay = AppConstants.retryBaseDelay * pow(2.0, Double(attempt - 1))
            Logger.vpn.info("Session creation failed, retrying in \(delay) seconds...")

            Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    self.connectWithRetry(to: connectionID, retryCount: retryCount, attempt: attempt + 1)
                } catch {
                    // Task was cancelled
                    return
                }
            }
        } else {
            Logger.vpn.error("Session creation failed after \(retryCount) attempts for: \(connectionID)")
            loadingError = .sessionCreationFailed(id: connectionID)
            resetConnectionToDisconnected(connectionID: connectionID)
        }
    }

    /// Resets connection status to disconnected.
    /// Used when connection attempts fail after all retries are exhausted.
    /// - Parameter connectionID: Connection identifier to reset status for.
    private func resetConnectionToDisconnected(connectionID: String) {
        setConnectionStatus(id: connectionID, status: .disconnected)
    }
    
    
    /// Disconnects the selected connection.
    /// - Parameter connectionID: Connection identifier.
    func disconnect(from connectionID: String) {
        Logger.vpn.info("Disconnecting from VPN: \(connectionID)")
        guard connections.contains(where: { $0.id == connectionID }) else {
            loadingError = .connectionNotFound(id: connectionID)
            Logger.vpn.error("Connection not found: \(connectionID)")
            return
        }

        Task { @MainActor in
            let hasSession = await sessionManager.hasSession(for: connectionID)
            guard hasSession else {
                loadingError = .sessionNotFound(id: connectionID)
                return
            }

            setConnectionStatus(id: connectionID, status: .disconnecting)

            // Cancel any existing timeout task for this connection
            disconnectTimeoutTasks[connectionID]?.cancel()

            // Create timeout task to handle disconnection timeout
            disconnectTimeoutTasks[connectionID] = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: UInt64(AppConstants.connectionTimeout * 1_000_000_000))
                    if !Task.isCancelled {
                        Logger.vpn.error("Disconnection timeout for: \(connectionID)")
                        self.loadingError = .connectionFailed(underlying: "Disconnection timeout after \(AppConstants.connectionTimeout) seconds")
                        self.setConnectionStatus(id: connectionID, status: .disconnected)
                        self.disconnectTimeoutTasks.removeValue(forKey: connectionID)
                        self.checkAndConnectPending()
                    }
                } catch {
                    // Task was cancelled - normal flow
                }
            }

            do {
                try await sessionManager.stopConnection(connectionID: connectionID)

                // Update status after disconnection
                await sessionManager.getSessionStatus(connectionID: connectionID) { [weak self] status in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.disconnectTimeoutTasks[connectionID]?.cancel()
                        self.disconnectTimeoutTasks.removeValue(forKey: connectionID)

                        if status == .disconnected {
                            Logger.vpn.info("Disconnected from VPN: \(connectionID)")
                            SoundFeedbackManager.shared.play(.disconnection)
                            StatisticsManager.shared.recordDisconnection()
                            if let connection = self.connections.first(where: { $0.id == connectionID }) {
                                ConnectionHistoryManager.shared.addEntry(
                                    connectionID: connectionID,
                                    connectionName: connection.name,
                                    action: .disconnected
                                )
                            }
                        }
                        self.handleStatusUpdate(connectionID: connectionID, scStatus: status)
                    }
                }
            } catch {
                disconnectTimeoutTasks[connectionID]?.cancel()
                disconnectTimeoutTasks.removeValue(forKey: connectionID)
                Logger.vpn.error("Disconnection failed: \(connectionID)")
                loadingError = .connectionFailed(underlying: error.localizedDescription)
                handleStatusUpdate(connectionID: connectionID, scStatus: .disconnected)
            }
        }
    }
    
    /// Toggles the state of the specified connection.
    /// If another connection is active, disconnects it first and queues the new connection.
    /// - Parameter connectionID: Connection identifier.
    func toggleConnection(_ connectionID: String) {
        guard let connection = connections.first(where: { $0.id == connectionID }) else {
            return
        }

        SettingsManager.shared.lastUsedConnectionID = connectionID

        if connection.status.isActive {
            pendingConnectionID = nil
            disconnect(from: connectionID)
        } else {
            let activeOthers = connections.filter { $0.id != connectionID && $0.status.isActive }
            if activeOthers.isEmpty {
                connect(to: connectionID, retryCount: AppConstants.defaultRetryCount)
            } else {
                pendingConnectionID = connectionID
                for active in activeOthers {
                    disconnect(from: active.id)
                }
            }
        }
    }
    
    /// Connects to the pending connection if all others are fully disconnected.
    private func checkAndConnectPending() {
        guard let pending = pendingConnectionID else { return }
        guard connections.contains(where: { $0.id == pending }) else {
            pendingConnectionID = nil
            return
        }
        let allOthersDisconnected = connections.allSatisfy {
            $0.id == pending || $0.status == .disconnected
        }
        guard allOthersDisconnected else { return }
        pendingConnectionID = nil
        connect(to: pending, retryCount: AppConstants.defaultRetryCount)
    }

    private func handleStatusUpdate(connectionID: String, scStatus: SCNetworkConnectionStatus) {
        guard let index = connections.firstIndex(where: { $0.id == connectionID }) else {
            return
        }

        let vpnStatus = convertToVPNStatus(from: scStatus)
        let oldStatus = connections[index].status

        if oldStatus != vpnStatus {
            var updatedConnections = connections
            updatedConnections[index].status = vpnStatus
            connections = updatedConnections
            updateActiveStatus()

            if oldStatus != .connected && vpnStatus == .connected {
                SoundFeedbackManager.shared.play(.connectionSuccess)
                StatisticsManager.shared.recordConnection()
                if let connection = connections.first(where: { $0.id == connectionID }) {
                    ConnectionHistoryManager.shared.addEntry(
                        connectionID: connectionID,
                        connectionName: connection.name,
                        action: .connected
                    )
                }
            }
        }

        checkAndConnectPending()
    }
    
    private func getCachedConnectionStatus(for identifier: String) async -> VPNConnection.VPNStatus {
        let scStatus = await sessionManager.getCachedStatus(for: identifier)
        return convertToVPNStatus(from: scStatus)
    }
    
    private func convertToVPNStatus(from scStatus: SCNetworkConnectionStatus) -> VPNConnection.VPNStatus {
        switch scStatus {
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .disconnecting:
            return .disconnecting
        case .disconnected, .invalid:
            return .disconnected
        @unknown default:
            return .disconnected
        }
    }
    
    private func processLoadedConnections(_ loadedConnections: [VPNConnection]) {
        Task { @MainActor in
            // Use TaskGroup to properly manage concurrent session creation
            await withTaskGroup(of: Void.self) { group in
                for connection in loadedConnections {
                    let identifierString = connection.id
                    
                    let hasSession = await sessionManager.hasSession(for: identifierString)
                    if !hasSession {
                        if let uuid = UUID(uuidString: identifierString) {
                            let nsUUID = uuid as NSUUID
                            group.addTask {
                                await self.sessionManager.getOrCreateSession(for: nsUUID)
                            }
                        }
                    }
                }
                
                // Wait for all session creation tasks to complete
                await group.waitForAll()
            }
            
            // Build processed connections after all sessions are created
            var processedConnections: [VPNConnection] = []
            for connection in loadedConnections {
                let identifierString = connection.id
                let status = await getCachedConnectionStatus(for: identifierString)
                
                processedConnections.append(VPNConnection(
                    id: identifierString,
                    name: connection.name,
                    serviceID: identifierString,
                    status: status
                ))
            }
            
            connections = processedConnections.sorted { $0.name < $1.name }
            
            if connections.isEmpty {
                loadingError = .noConfigurations
            }
            
            updateActiveStatus()
        }
    }
    
    private func handleLoadError(_ error: VPNError) {
        loadingError = error
        connections = []
        updateActiveStatus()
    }
    
    private func refreshAllStatuses() {
        Task { @MainActor in
            for connection in connections {
                await sessionManager.getSessionStatus(connectionID: connection.id) { [weak self] status in
                    Task { @MainActor in
                        self?.handleStatusUpdate(connectionID: connection.id, scStatus: status)
                    }
                }
            }
        }
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        let effectiveInterval = max(AppConstants.minUpdateInterval, updateInterval)
        
        let timer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                let now = Date()
                let needsFullReload = now.timeIntervalSince(self.lastFullReload) >= self.connectionsListReloadInterval
                self.loadConnections(forceReload: needsFullReload)
            }
        }
        
        updateTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func restartMonitoring() {
        startMonitoring()
    }
    
    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateActiveStatus() {
        hasActiveConnection = connections.contains { $0.status.isActive }
    }
    
    /// Releases resources when the application terminates.
    func cleanup() {
        stopMonitoring()
        loadTask?.cancel()
        loadTask = nil
        for (_, task) in disconnectTimeoutTasks {
            task.cancel()
        }
        disconnectTimeoutTasks.removeAll()
        if let token = statusObserverToken {
            NotificationCenter.default.removeObserver(token)
            statusObserverToken = nil
        }

        Task {
            await sessionManager.cleanup()
        }
    }
}

