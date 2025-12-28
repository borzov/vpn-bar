import Foundation
import SystemConfiguration
import Darwin
import os.log

/// Менеджер VPN-соединений, отвечающий за загрузку конфигураций и управление сессиями.
@MainActor
class VPNManager: VPNManagerProtocol {
    static let shared: VPNManager = {
        let statusHandler: ((String, SCNetworkConnectionStatus) -> Void) = { connectionID, status in
            Task { @MainActor in
                VPNManager.shared.updateConnectionStatus(identifier: connectionID, newStatus: status)
            }
        }
        return VPNManager(
            configurationLoader: VPNConfigurationLoader(),
            sessionManager: VPNSessionManager(statusUpdateHandler: statusHandler)
        )
    }()
    
    @Published var connections: [VPNConnection] = []
    @Published var hasActiveConnection: Bool = false
    @Published var loadingError: VPNError?
    
    private let configurationLoader: VPNConfigurationLoaderProtocol
    private let sessionManager: VPNSessionManagerProtocol
    private var updateTimer: Timer?
    private var loadTask: Task<Void, Never>?
    
    /// Интервал обновления списка соединений; при изменении перезапускает мониторинг.
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
        sessionManager: VPNSessionManagerProtocol? = nil
    ) {
        if let loader = configurationLoader {
            self.configurationLoader = loader
        } else {
            self.configurationLoader = VPNConfigurationLoader()
        }
        
        // Создаем sessionManager с обработчиком обновления статусов
        var handler: ((String, SCNetworkConnectionStatus) -> Void)?
        if sessionManager == nil {
            handler = { connectionID, status in
                Task { @MainActor in
                    VPNManager.shared.updateConnectionStatus(identifier: connectionID, newStatus: status)
                }
            }
        }
        self.sessionManager = sessionManager ?? VPNSessionManager(statusUpdateHandler: handler)
        
        _ = updateInterval
        
        loadConnections(forceReload: true)
        lastFullReload = Date()
        startMonitoring()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        // Note: deinit не может вызывать @MainActor методы синхронно
        // Очистка будет выполнена при завершении приложения через AppDelegate
    }
    
    /// Загружает доступные VPN-конфигурации.
    /// - Parameter forceReload: Принудительно перезагружает даже при наличии кэша.
    func loadConnections(forceReload: Bool = false) {
        loadTask?.cancel()
        
        if forceReload {
            lastFullReload = Date()
        }
        
        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            
            loadingError = nil
            
            configurationLoader.loadConfigurations { [weak self] result in
                Task { @MainActor in
                    guard let self = self, !Task.isCancelled else { return }
                    
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
    
    /// Подключает выбранное соединение.
    /// - Parameters:
    ///   - connectionID: Идентификатор соединения.
    ///   - retryCount: Количество попыток подключения (по умолчанию 3).
    func connect(to connectionID: String, retryCount: Int = AppConstants.defaultRetryCount) {
        connectWithRetry(to: connectionID, retryCount: retryCount, attempt: 1)
    }
    
    private func connectWithRetry(to connectionID: String, retryCount: Int, attempt: Int) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            loadingError = .connectionNotFound(id: connectionID)
            Logger.vpn.error("Connection not found: \(connectionID)")
            return
        }
        
        if sessionManager.hasSession(for: connectionID) {
            do {
                try sessionManager.startConnection(connectionID: connectionID)
                updateConnectionToConnecting(connectionID: connectionID)
            } catch {
                Logger.vpn.error("Failed to start connection: \(error.localizedDescription)")
                if attempt < retryCount {
                    let delay = AppConstants.retryBaseDelay * pow(2.0, Double(attempt - 1))
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        self.connectWithRetry(to: connectionID, retryCount: retryCount, attempt: attempt + 1)
                    }
                } else {
                    loadingError = error as? VPNError ?? .connectionFailed(underlying: error.localizedDescription)
                }
            }
        } else {
            if let uuid = UUID(uuidString: connectionID) {
                let nsUUID = uuid as NSUUID
                Task { @MainActor in
                    await self.sessionManager.getOrCreateSession(for: nsUUID)
                    if self.sessionManager.hasSession(for: connectionID) {
                        do {
                            try self.sessionManager.startConnection(connectionID: connectionID)
                            self.updateConnectionToConnecting(connectionID: connectionID)
                        } catch {
                            self.handleConnectionFailure(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
                        }
                    } else {
                        self.handleConnectionFailure(connectionID: connectionID, retryCount: retryCount, attempt: attempt)
                    }
                }
            } else {
                loadingError = .sessionNotFound(id: connectionID)
                Logger.vpn.error("Invalid UUID for connection: \(connectionID)")
            }
        }
    }
    
    private func updateConnectionToConnecting(connectionID: String) {
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .connecting {
                var updatedConnections = connections
                updatedConnections[index].status = .connecting
                connections = updatedConnections
                updateActiveStatus()
            }
        }
    }
    
    
    private func handleConnectionFailure(connectionID: String, retryCount: Int, attempt: Int) {
        if attempt < retryCount {
            let delay = AppConstants.retryBaseDelay * pow(2.0, Double(attempt - 1))
            Logger.vpn.info("Session creation failed, retrying in \(delay) seconds...")
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                self.connectWithRetry(to: connectionID, retryCount: retryCount, attempt: attempt + 1)
            }
        } else {
            Logger.vpn.error("Session creation failed after \(retryCount) attempts for: \(connectionID)")
            loadingError = .sessionCreationFailed(id: connectionID)
        }
    }
    
    
    /// Отключает выбранное соединение.
    /// - Parameter connectionID: Идентификатор соединения.
    func disconnect(from connectionID: String) {
        Logger.vpn.info("Disconnecting from VPN: \(connectionID)")
        guard connections.contains(where: { $0.id == connectionID }) else {
            loadingError = .connectionNotFound(id: connectionID)
            Logger.vpn.error("Connection not found: \(connectionID)")
            return
        }
        
        guard sessionManager.hasSession(for: connectionID) else {
            loadingError = .sessionNotFound(id: connectionID)
            return
        }
        
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .disconnecting {
                var updatedConnections = connections
                updatedConnections[index].status = .disconnecting
                connections = updatedConnections
                updateActiveStatus()
            }
        }
        
        var timeoutTask: Task<Void, Never>?
        
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(AppConstants.connectionTimeout * 1_000_000_000))
            if !Task.isCancelled {
                Logger.vpn.error("Disconnection timeout for: \(connectionID)")
                self.loadingError = .connectionFailed(underlying: "Disconnection timeout after \(AppConstants.connectionTimeout) seconds")
                if let index = self.connections.firstIndex(where: { $0.id == connectionID }) {
                    var updatedConnections = self.connections
                    updatedConnections[index].status = .disconnected
                    self.connections = updatedConnections
                    self.updateActiveStatus()
                }
            }
        }
        
        do {
            try sessionManager.stopConnection(connectionID: connectionID)
            
            // Обновляем статус после отключения
            sessionManager.getSessionStatus(connectionID: connectionID) { [weak self] status in
                Task { @MainActor in
                    guard let self = self else { return }
                    timeoutTask?.cancel()
                    timeoutTask = nil
                    
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
                    self.updateConnectionStatus(identifier: connectionID, newStatus: status)
                }
            }
        } catch {
            timeoutTask?.cancel()
            timeoutTask = nil
            Logger.vpn.error("Disconnection failed: \(connectionID)")
            loadingError = .connectionFailed(underlying: error.localizedDescription)
            updateConnectionStatus(identifier: connectionID, newStatus: .disconnected)
        }
    }
    
    /// Переключает состояние указанного соединения.
    /// - Parameter connectionID: Идентификатор соединения.
    func toggleConnection(_ connectionID: String) {
        guard let connection = connections.first(where: { $0.id == connectionID }) else {
            return
        }
        
        SettingsManager.shared.lastUsedConnectionID = connectionID
        
        if connection.status.isActive {
            disconnect(from: connectionID)
        } else {
            connect(to: connectionID, retryCount: AppConstants.defaultRetryCount)
        }
    }
    
    /// Отключает все активные VPN-подключения.
    func disconnectAll() {
        let activeConnections = connections.filter { $0.status.isActive }
        
        for connection in activeConnections {
            disconnect(from: connection.id)
        }
    }

    
    private func updateConnectionStatus(identifier: String, newStatus: SCNetworkConnectionStatus) {
        guard let index = connections.firstIndex(where: { $0.id == identifier }) else {
            return
        }
        
        let vpnStatus = convertToVPNStatus(from: newStatus)
        let oldStatus = connections[index].status
        
        if oldStatus != vpnStatus {
            var updatedConnections = connections
            updatedConnections[index].status = vpnStatus
            connections = updatedConnections
            updateActiveStatus()
            
            if oldStatus != .connected && vpnStatus == .connected {
                SoundFeedbackManager.shared.play(.connectionSuccess)
                StatisticsManager.shared.recordConnection()
                if let connection = connections.first(where: { $0.id == identifier }) {
                    ConnectionHistoryManager.shared.addEntry(
                        connectionID: identifier,
                        connectionName: connection.name,
                        action: .connected
                    )
                }
            }
        }
    }
    
    private func getCachedConnectionStatus(for identifier: String) -> VPNConnection.VPNStatus {
        let scStatus = sessionManager.getCachedStatus(for: identifier)
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
        var processedConnections: [VPNConnection] = []
        
        for connection in loadedConnections {
            let identifierString = connection.id
            
            if !sessionManager.hasSession(for: identifierString) {
                if let uuid = UUID(uuidString: identifierString) {
                    let nsUUID = uuid as NSUUID
                    Task { @MainActor in
                        await self.sessionManager.getOrCreateSession(for: nsUUID)
                    }
                }
            }
            
            let status = getCachedConnectionStatus(for: identifierString)
            
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
    
    private func handleLoadError(_ error: VPNError) {
        loadingError = error
        connections = []
        updateActiveStatus()
    }
    
    private func refreshAllStatuses() {
        for connection in connections {
            sessionManager.getSessionStatus(connectionID: connection.id) { [weak self] status in
                Task { @MainActor in
                    self?.updateConnectionStatus(identifier: connection.id, newStatus: status)
                }
            }
        }
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        let effectiveInterval = max(AppConstants.minUpdateInterval, updateInterval)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                
                let now = Date()
                let needsFullReload = now.timeIntervalSince(self.lastFullReload) >= self.connectionsListReloadInterval
                self.loadConnections(forceReload: needsFullReload)
            }
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
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
    
    /// Освобождает ресурсы при завершении приложения.
    func cleanup() {
        stopMonitoring()
        sessionManager.cleanup()
    }
}

