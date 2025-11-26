import Foundation
import SystemConfiguration
import Darwin

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
    
    // Настройки обновления
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
    // ИЗМЕНЕНО: Увеличен интервал обновления статусов
    private let statusUpdateInterval: TimeInterval = AppConstants.sessionStatusUpdateInterval
    
    private init() {
        // Загружаем настройки
        _ = updateInterval // Инициализируем из UserDefaults
        
        loadConnections()
        startMonitoring()
    }
    
    deinit {
        // Останавливаем таймеры напрямую
        updateTimer?.invalidate()
        updateTimer = nil
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
        
        // Освобождаем все сессии
        for (_, session) in sessions {
            ne_session_cancel(session)
            ne_session_release(session)
        }
        sessions.removeAll()
    }
    
    // MARK: - Public Methods
    
    func loadConnections(forceReload: Bool = false) {
        // В начале метода:
        loadingError = nil
        
        // Сначала загружаем NetworkExtension framework если еще не загружен
        loadNetworkExtensionFrameworkIfNeeded()
        
        // Используем NEConfigurationManager через Objective-C runtime
        // Пробуем получить класс напрямую
        let managerClass: AnyClass? = NSClassFromString("NEConfigurationManager")
        
        guard let managerType = managerClass as? NSObject.Type else {
            // Альтернативный способ - через прямой вызов
            self.loadConnectionsAlternative()
            return
        }
        
        // Вызываем sharedManager
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
        
        // Вызываем loadConfigurationsWithCompletionQueue:handler:
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
                
                // NSArray из Objective-C нужно приводить через [Any] сначала
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
                    
                    // Получаем имя и identifier через KVC
                    let name = config.value(forKey: "name") as? String
                    let identifier = config.value(forKey: "identifier") as? NSUUID
                    
                    guard let name = name, let identifier = identifier else {
                        continue
                    }
                    
                    // Пропускаем внутренние конфигурации macOS
                    if name.hasPrefix("com.apple.preferences.") {
                        continue
                    }
                    
                    let identifierString = identifier.uuidString
                    
                    // Получаем или создаем сессию для этого VPN (только если нужно)
                    if self.sessions[identifierString] == nil {
                        self.getOrCreateSession(for: identifier)
                    }
                    
                    // Получаем статус из кэша (не делаем синхронный запрос)
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
                
                // НОВОЕ: Устанавливаем сообщение об ошибке если нет подключений
                if self.connections.isEmpty {
                    self.loadingError = NSLocalizedString(
                        "No VPN configurations found. Configure VPN in System Preferences → Network.",
                        comment: ""
                    )
                }
                
                self.updateActiveStatus()
                
                // Обновляем статусы только если прошло достаточно времени
                let now = Date()
                if now.timeIntervalSince(self.lastStatusUpdate) >= self.statusUpdateInterval {
                    self.lastStatusUpdate = now
                    self.refreshAllStatuses()
                }
            }
        }
        
        // Упаковываем block в объект
        let block = unsafeBitCast(handler, to: AnyObject.self)
        
        // Используем method invocation через runtime
        let queue = self.sessionQueue
        let imp = manager.method(for: selector)
        
        // Вызываем метод напрямую через IMP
        typealias MethodType = @convention(c) (AnyObject, Selector, DispatchQueue, AnyObject) -> Void
        let method = unsafeBitCast(imp, to: MethodType.self)
        method(manager, selector, queue, block)
    }
    
    private func loadConnectionsAlternative() {
        // Альтернативный способ - используем dlopen для загрузки NetworkExtension framework
        let frameworkPath = "/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension"
        guard let framework = dlopen(frameworkPath, RTLD_LAZY) else {
            let error = String(cString: dlerror())
            print(String(format: NSLocalizedString("Failed to load NetworkExtension framework: %@", comment: ""), error))
            self.connections = []
            self.updateActiveStatus()
            return
        }
        
        defer { dlclose(framework) }
        
        // Пробуем получить класс снова
        guard let managerClass = NSClassFromString("NEConfigurationManager") as? NSObject.Type else {
            // Пробуем через objc runtime напрямую
            if objc_getClass("NEConfigurationManager") != nil {
                // Продолжаем с обычным вызовом
                self.loadConnections()
            } else {
                self.connections = []
                self.updateActiveStatus()
            }
            return
        }
        
        // Продолжаем как обычно - рекурсивный вызов, но теперь класс должен быть доступен
        // Но чтобы избежать бесконечной рекурсии, вызываем напрямую логику
        self.loadConnectionsWithManagerClass(managerClass)
    }
    
    private func loadConnectionsWithManagerClass(_ managerType: NSObject.Type) {
        // Дублируем логику из loadConnections, но с уже известным классом
        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard managerType.responds(to: sharedManagerSelector) else {
            print(NSLocalizedString("Error: sharedManager unavailable", comment: ""))
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
                
                // НОВОЕ: Устанавливаем сообщение об ошибке если нет подключений
                if self.connections.isEmpty {
                    self.loadingError = NSLocalizedString(
                        "No VPN configurations found. Configure VPN in System Preferences → Network.",
                        comment: ""
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
    
    func connect(to connectionID: String) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            print(String(format: NSLocalizedString("VPN connection not found: %@", comment: ""), connectionID))
            return
        }
        
        guard let session = sessions[connectionID] else {
            print(String(format: NSLocalizedString("VPN session not found for %@, creating...", comment: ""), connectionID))
            // Пытаемся создать сессию заново
            if let uuid = UUID(uuidString: connectionID) {
                let nsUUID = uuid as NSUUID
                getOrCreateSession(for: nsUUID)
                if let newSession = sessions[connectionID] {
                    ne_session_start(newSession)
                }
            }
            return
        }
        
        // Сразу устанавливаем статус connecting для анимации
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .connecting {
                // Создаем новый массив для триггера @Published
                var updatedConnections = connections
                updatedConnections[index].status = .connecting
                // Принудительно триггерим обновление
                objectWillChange.send()
                connections = updatedConnections
                updateActiveStatus()
            }
        }
        
        // Используем ne_session_start() как в VPNStatus
        ne_session_start(session)
        
        // Обновляем статус после небольшой задержки (только для этого подключения)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let session = self.sessions[connectionID] {
                self.refreshSessionStatus(for: connectionID, session: session, updateConnections: true)
            }
        }
    }
    
    func disconnect(from connectionID: String) {
        guard connections.contains(where: { $0.id == connectionID }) else {
            print(String(format: NSLocalizedString("VPN connection not found: %@", comment: ""), connectionID))
            return
        }
        
        guard let session = sessions[connectionID] else {
            print(String(format: NSLocalizedString("VPN session not found for %@", comment: ""), connectionID))
            return
        }
        
        // Сразу устанавливаем статус disconnecting для анимации
        if let index = connections.firstIndex(where: { $0.id == connectionID }) {
            if connections[index].status != .disconnecting {
                // Создаем новый массив для триггера @Published
                var updatedConnections = connections
                updatedConnections[index].status = .disconnecting
                // Принудительно триггерим обновление
                objectWillChange.send()
                connections = updatedConnections
                updateActiveStatus()
            }
        }
        
        // Используем ne_session_stop() как в VPNStatus
        ne_session_stop(session)
        
        // Обновляем статус после небольшой задержки (только для этого подключения)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let session = self.sessions[connectionID] {
                self.refreshSessionStatus(for: connectionID, session: session, updateConnections: true)
            }
        }
    }
    
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
    
    /// Отключает все активные VPN-подключения
    func disconnectAll() {
        let activeConnections = connections.filter { $0.status.isActive }
        
        for connection in activeConnections {
            disconnect(from: connection.id)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadNetworkExtensionFrameworkIfNeeded() {
        if networkExtensionFrameworkLoaded {
            return
        }
        
        // Пробуем загрузить NetworkExtension framework разными способами
        let possiblePaths = [
            "/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension",
            "/System/Library/Frameworks/NetworkExtension.framework/Versions/A/NetworkExtension",
            "/System/Library/Frameworks/NetworkExtension.framework"
        ]
        
        var frameworkLoaded = false
        for frameworkPath in possiblePaths {
            if dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL) != nil {
                frameworkLoaded = true
                // Не закрываем framework, он должен остаться загруженным
                break
            }
        }
        
        if !frameworkLoaded {
            // Пробуем через Bundle
            if Bundle(identifier: "com.apple.NetworkExtension") != nil {
                frameworkLoaded = true
            }
        }
        
        networkExtensionFrameworkLoaded = frameworkLoaded
    }
    
    private nonisolated func getOrCreateSession(for uuid: NSUUID) {
        let identifier = uuid.uuidString
        
        // Создаем новую сессию как в VPNStatus
        var uuidBytes: uuid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        uuid.getBytes(&uuidBytes)
        
        // Передаем указатель на uuidBytes
        withUnsafePointer(to: &uuidBytes) { uuidPtr in
            guard let session = ne_session_create(uuidPtr, NESessionTypeVPN) else {
                print(String(format: NSLocalizedString("Error creating session for %@", comment: ""), identifier))
                return
            }
            
            Task { @MainActor in
                // Проверяем еще раз на main actor
                if self.sessions[identifier] == nil {
                    self.sessions[identifier] = session
                    
                    // Настраиваем обработчик событий
                    ne_session_set_event_handler(session, self.sessionQueue) { event, eventData in
                        // Обновляем только статус, не перезагружаем весь список
                        Task { @MainActor in
                            VPNManager.shared.refreshSessionStatus(for: identifier, session: session, updateConnections: true)
                        }
                    }
                    
                    // Получаем начальный статус
                    self.refreshSessionStatus(for: identifier, session: session, updateConnections: false)
                } else {
                    // Сессия уже существует, освобождаем созданную
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
                
                // Обновляем только если статус изменился или требуется принудительное обновление
                if oldStatus != scStatus || updateConnections {
                    self.updateConnectionStatus(identifier: identifier, newStatus: scStatus)
                }
            }
        }
    }
    
    private func updateConnectionStatus(identifier: String, newStatus: SCNetworkConnectionStatus) {
        // Обновляем статус только для конкретного подключения, не перезагружая весь список
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
            // Создаем новый массив для триггера @Published
            var updatedConnections = connections
            updatedConnections[index].status = vpnStatus
            // Принудительно триггерим обновление
            objectWillChange.send()
            connections = updatedConnections
            updateActiveStatus()
        }
    }
    
    private func getCachedConnectionStatus(for identifier: String) -> VPNConnection.VPNStatus {
        // Используем только сохраненный статус (без обновления)
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
        // Обновляем статусы всех сессий асинхронно (без обновления списка подключений)
        for (identifier, session) in sessions {
            refreshSessionStatus(for: identifier, session: session, updateConnections: false)
        }
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        // Обновляем список подключений с настраиваемым интервалом
        // Увеличиваем минимальный интервал до 15 секунд
        let effectiveInterval = max(AppConstants.minUpdateInterval, updateInterval)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: effectiveInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadConnections(forceReload: false)
            }
        }
        RunLoop.current.add(updateTimer!, forMode: .common)
        
        // Таймер для обновления статусов - только как резервный механизм
        // Event handlers в ne_session_set_event_handler должны обрабатывать большинство изменений
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

