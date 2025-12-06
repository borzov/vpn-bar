import Foundation
import SystemConfiguration
import Darwin

/// Менеджер VPN-соединений, отвечающий за загрузку конфигураций и управление сессиями.
@MainActor
class VPNManager: VPNManagerProtocol {
    static let shared = VPNManager()
    
    @Published var connections: [VPNConnection] = []
    @Published var hasActiveConnection: Bool = false
    @Published var loadingError: String?
    
    private var sessions: [String: ne_session_t] = [:]
    private var sessionStatuses: [String: SCNetworkConnectionStatus] = [:]
    private let sessionQueue = DispatchQueue(label: "VPNBarApp.sessionQueue")
    private var updateTimer: Timer?
    private var statusUpdateTimer: Timer?
    private var networkExtensionFrameworkLoaded = false
    
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
    private let statusUpdateInterval: TimeInterval = AppConstants.sessionStatusUpdateInterval
    
    private init() {
        _ = updateInterval
        
        loadConnections()
        startMonitoring()
    }
    
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        
        for (_, session) in sessions {
            ne_session_cancel(session)
            ne_session_release(session)
        }
        sessions.removeAll()
    }
    
    /// Загружает доступные VPN-конфигурации.
    /// - Parameter forceReload: Принудительно перезагружает даже при наличии кэша.
    func loadConnections(forceReload: Bool = false) {
        loadingError = nil
        
        loadNetworkExtensionFrameworkIfNeeded()
        
        let managerClass: AnyClass? = NSClassFromString("NEConfigurationManager")
        
        guard let managerType = managerClass as? NSObject.Type else {
            self.loadConnectionsAlternative()
            return
        }
        
        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard managerType.responds(to: sharedManagerSelector) else {
            self.connections = []
            self.updateActiveStatus()
            return
        }
        
        let sharedManagerResult = managerType.perform(sharedManagerSelector)
        guard let manager = sharedManagerResult?.takeUnretainedValue() as? NSObject else {
            self.connections = []
            self.updateActiveStatus()
            return
        }
        
        let selector = NSSelectorFromString("loadConfigurationsWithCompletionQueue:handler:")
        guard manager.responds(to: selector) else {
            self.connections = []
            self.updateActiveStatus()
            return
        }
        
        let handler: @convention(block) (NSArray?, NSError?) -> Void = { [weak self] configurations, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if error != nil {
                    self.connections = []
                    self.updateActiveStatus()
                    return
                }
                
                guard let nsArray = configurations as NSArray? else {
                    self.connections = []
                    self.updateActiveStatus()
                    return
                }
                
                var connections: [VPNConnection] = []
                
                for index in 0..<nsArray.count {
                    guard let config = nsArray[index] as? NSObject else {
                        continue
                    }
                    
                    let name = config.value(forKey: "name") as? String
                    let identifier = config.value(forKey: "identifier") as? NSUUID
                    
                    guard let name = name, let identifier = identifier else {
                        continue
                    }
                    
                    if name.hasPrefix("com.apple.preferences.") {
                        continue
                    }
                    
                    let identifierString = identifier.uuidString
                    
                    if self.sessions[identifierString] == nil {
                        self.getOrCreateSession(for: identifier)
                    }
                    
                    let status = self.getCachedConnectionStatus(for: identifierString)
                    
                    let connection = VPNConnection(
                        id: identifierString,
                        name: name,
                        serviceID: identifierString,
                        status: status
                    )
                    
                    connections.append(connection)
                }
                
                self.connections = connections.sorted { $0.name < $1.name }
                
                if self.connections.isEmpty {
                    self.loadingError = NSLocalizedString(
                        "error.vpn.noConfigurations",
                        comment: "Shown when no VPN configurations are present"
                    )
                }
                
                self.updateActiveStatus()
                
                let now = Date()
                if now.timeIntervalSince(self.lastStatusUpdate) >= self.statusUpdateInterval {
                    self.lastStatusUpdate = now
                    self.refreshAllStatuses()
                }
            }
        }
        
        let block = unsafeBitCast(handler, to: AnyObject.self)
        
        let queue = self.sessionQueue
        let imp = manager.method(for: selector)
        
        typealias MethodType = @convention(c) (AnyObject, Selector, DispatchQueue, AnyObject) -> Void
        let method = unsafeBitCast(imp, to: MethodType.self)
        method(manager, selector, queue, block)
    }
    
    private func loadConnectionsAlternative() {
        let frameworkPath = "/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension"
        guard let framework = dlopen(frameworkPath, RTLD_LAZY) else {
            let error = String(cString: dlerror())
            print(
                String(
                    format: NSLocalizedString(
                        "error.vpn.loadFrameworkFailed",
                        comment: "Error when NetworkExtension framework fails to load"
                    ),
                    error
                )
            )
            self.connections = []
            self.updateActiveStatus()
            return
        }
        
        defer { dlclose(framework) }
        
        guard let managerClass = NSClassFromString("NEConfigurationManager") as? NSObject.Type else {
            if objc_getClass("NEConfigurationManager") != nil {
                self.loadConnections()
            } else {
                self.connections = []
                self.updateActiveStatus()
            }
            return
        }
        
        self.loadConnectionsWithManagerClass(managerClass)
    }
    
    private func loadConnectionsWithManagerClass(_ managerType: NSObject.Type) {
        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard managerType.responds(to: sharedManagerSelector) else {
            print(
                NSLocalizedString(
                    "error.vpn.sharedManagerUnavailable",
                    comment: "Error when sharedManager selector is unavailable"
                )
            )
            return
        }
        
        let sharedManagerResult = managerType.perform(sharedManagerSelector)
        guard let manager = sharedManagerResult?.takeUnretainedValue() as? NSObject else {
            return
        }
        
        let selector = NSSelectorFromString("loadConfigurationsWithCompletionQueue:handler:")
        guard manager.responds(to: selector) else {
            return
        }
        
        let handler: @convention(block) (NSArray?, NSError?) -> Void = { [weak self] configurations, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if error != nil {
                    self.connections = []
                    self.updateActiveStatus()
                    return
                }
                
                guard let nsArray = configurations as NSArray? else {
                    self.connections = []
                    self.updateActiveStatus()
                    return
                }
                
                var connections: [VPNConnection] = []
                
                for index in 0..<nsArray.count {
                    guard let config = nsArray[index] as? NSObject else {
                        continue
                    }
                    
                    let name = config.value(forKey: "name") as? String
                    let identifier = config.value(forKey: "identifier") as? NSUUID
                    
                    guard let name = name, let identifier = identifier,
                          !name.hasPrefix("com.apple.preferences.") else {
                        continue
                    }
                    
                    let identifierString = identifier.uuidString
                    
                    if self.sessions[identifierString] == nil {
                        self.getOrCreateSession(for: identifier)
                    }
                    
                    let status = self.getCachedConnectionStatus(for: identifierString)
                    
                    connections.append(VPNConnection(
                        id: identifierString,
                        name: name,
                        serviceID: identifierString,
                        status: status
                    ))
                }
                
                self.connections = connections.sorted { $0.name < $1.name }
                
                if self.connections.isEmpty {
                    self.loadingError = NSLocalizedString(
                        "error.vpn.noConfigurations",
                        comment: "Shown when no VPN configurations are present"
                    )
                }
                
                self.updateActiveStatus()
                self.refreshAllStatuses()
            }
        }
        
        let block = unsafeBitCast(handler, to: AnyObject.self)
        let queue = self.sessionQueue
        let imp = manager.method(for: selector)
        typealias MethodType = @convention(c) (AnyObject, Selector, DispatchQueue, AnyObject) -> Void
        let method = unsafeBitCast(imp, to: MethodType.self)
        method(manager, selector, queue, block)
    }
    
    /// Подключает выбранное соединение.
    /// - Parameter connectionID: Идентификатор соединения.
    func connect(to connectionID: String) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            print(
                String(
                    format: NSLocalizedString(
                        "error.vpn.connectionNotFound",
                        comment: "Error when VPN connection ID is missing"
                    ),
                    connectionID
                )
            )
            return
        }
        
        guard let session = sessions[connectionID] else {
            print(
                String(
                    format: NSLocalizedString(
                        "error.vpn.sessionNotFoundCreating",
                        comment: "Session missing; creating a new one"
                    ),
                    connectionID
                )
            )
            if let uuid = UUID(uuidString: connectionID) {
                let nsUUID = uuid as NSUUID
                getOrCreateSession(for: nsUUID)
                if let newSession = sessions[connectionID] {
                    ne_session_start(newSession)
                }
            }
            return
        }
        
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .connecting {
                var updatedConnections = connections
                updatedConnections[index].status = .connecting
                objectWillChange.send()
                connections = updatedConnections
                updateActiveStatus()
            }
        }
        
        ne_session_start(session)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let session = self.sessions[connectionID] {
                self.refreshSessionStatus(for: connectionID, session: session, updateConnections: true)
            }
        }
    }
    
    /// Отключает выбранное соединение.
    /// - Parameter connectionID: Идентификатор соединения.
    func disconnect(from connectionID: String) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            print(
                String(
                    format: NSLocalizedString(
                        "error.vpn.connectionNotFound",
                        comment: "Error when VPN connection ID is missing"
                    ),
                    connectionID
                )
            )
            return
        }
        
        guard let session = sessions[connectionID] else {
            print(
                String(
                    format: NSLocalizedString(
                        "error.vpn.sessionNotFound",
                        comment: "Session missing for connection"
                    ),
                    connectionID
                )
            )
            return
        }
        
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .disconnecting {
                var updatedConnections = connections
                updatedConnections[index].status = .disconnecting
                objectWillChange.send()
                connections = updatedConnections
                updateActiveStatus()
            }
        }
        
        ne_session_stop(session)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let session = self.sessions[connectionID] {
                self.refreshSessionStatus(for: connectionID, session: session, updateConnections: true)
            }
        }
    }
    
    /// Переключает состояние указанного соединения.
    /// - Parameter connectionID: Идентификатор соединения.
    func toggleConnection(_ connectionID: String) {
        guard let connection = connections.first(where: { $0.id == connectionID }) else {
            return
        }
        
        if connection.status.isActive {
            disconnect(from: connectionID)
        } else {
            connect(to: connectionID)
        }
    }
    
    /// Отключает все активные VPN-подключения.
    func disconnectAll() {
        let activeConnections = connections.filter { $0.status.isActive }
        
        for connection in activeConnections {
            disconnect(from: connection.id)
        }
    }

    private func loadNetworkExtensionFrameworkIfNeeded() {
        if networkExtensionFrameworkLoaded {
            return
        }
        
        let possiblePaths = [
            "/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension",
            "/System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension",
            "/System/Library/Frameworks/NetworkExtension.framework"
        ]
        
        var frameworkLoaded = false
        for frameworkPath in possiblePaths {
            if dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL) != nil {
                frameworkLoaded = true
                break
            }
        }
        
        if !frameworkLoaded {
            if Bundle(identifier: "com.apple.NetworkExtension") != nil {
                frameworkLoaded = true
            }
        }
        
        networkExtensionFrameworkLoaded = frameworkLoaded
    }
    
    private nonisolated func getOrCreateSession(for uuid: NSUUID) {
        let identifier = uuid.uuidString
        
        var uuidBytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        uuid.getBytes(&uuidBytes)
        
        withUnsafePointer(to: &uuidBytes) { uuidPtr in
            guard let session = ne_session_create(uuidPtr, NESessionTypeVPN) else {
                print(
                    String(
                        format: NSLocalizedString(
                            "error.vpn.sessionCreateFailed",
                            comment: "Error when session creation fails"
                        ),
                        identifier
                    )
                )
                return
            }
            
            Task { @MainActor in
                if self.sessions[identifier] == nil {
                    self.sessions[identifier] = session
                    
                    ne_session_set_event_handler(session, self.sessionQueue) { event, eventData in
                        Task { @MainActor in
                            VPNManager.shared.refreshSessionStatus(for: identifier, session: session, updateConnections: true)
                        }
                    }
                    
                    self.refreshSessionStatus(for: identifier, session: session, updateConnections: false)
                } else {
                    ne_session_release(session)
                }
            }
        }
        
    }
    
    private func refreshSessionStatus(for identifier: String, session: ne_session_t, updateConnections: Bool = false) {
        ne_session_get_status(session, sessionQueue) { status in
            Task { @MainActor in
                let scStatus = SCNetworkConnectionGetStatusFromNEStatus(status)
                let oldStatus = self.sessionStatuses[identifier]
                self.sessionStatuses[identifier] = scStatus
                
                if oldStatus != scStatus || updateConnections {
                    self.updateConnectionStatus(identifier: identifier, newStatus: scStatus)
                }
            }
        }
    }
    
    private func updateConnectionStatus(identifier: String, newStatus: SCNetworkConnectionStatus) {
        guard let index = connections.firstIndex(where: { $0.id == identifier }) else {
            return
        }
        
        let vpnStatus: VPNConnection.VPNStatus
        switch newStatus {
        case .connected:
            vpnStatus = .connected
        case .connecting:
            vpnStatus = .connecting
        case .disconnecting:
            vpnStatus = .disconnecting
        case .disconnected, .invalid:
            vpnStatus = .disconnected
        @unknown default:
            vpnStatus = .disconnected
        }
        
        if connections[index].status != vpnStatus {
            var updatedConnections = connections
            updatedConnections[index].status = vpnStatus
            objectWillChange.send()
            connections = updatedConnections
            updateActiveStatus()
        }
    }
    
    private func getCachedConnectionStatus(for identifier: String) -> VPNConnection.VPNStatus {
        let scStatus = sessionStatuses[identifier] ?? .invalid
        
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
    
    private func refreshAllStatuses() {
        for (identifier, session) in sessions {
            refreshSessionStatus(for: identifier, session: session, updateConnections: false)
        }
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        let effectiveInterval = max(AppConstants.minUpdateInterval, updateInterval)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadConnections(forceReload: false)
            }
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
        
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: statusUpdateInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshAllStatuses()
            }
        }
        RunLoop.current.add(statusUpdateTimer!, forMode: .common)
    }
    
    private func restartMonitoring() {
        startMonitoring()
    }
    
    private func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    private func updateActiveStatus() {
        hasActiveConnection = connections.contains { $0.status.isActive }
    }
}

