import Foundation
import Darwin
import os.log

/// Загружает VPN-конфигурации из системы.
@MainActor
final class VPNConfigurationLoader: VPNConfigurationLoaderProtocol {
    private let sessionQueue = DispatchQueue(label: "VPNBarApp.configurationLoader")
    private var networkExtensionFrameworkLoaded = false
    
    func loadConfigurations(completion: @escaping (Result<[VPNConnection], VPNError>) -> Void) {
        loadNetworkExtensionFrameworkIfNeeded()
        
        let managerClass: AnyClass? = NSClassFromString("NEConfigurationManager")
        
        guard let managerType = managerClass as? NSObject.Type else {
            loadConfigurationsAlternative(completion: completion)
            return
        }
        
        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard managerType.responds(to: sharedManagerSelector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let sharedManagerResult = managerType.perform(sharedManagerSelector)
        guard let manager = sharedManagerResult?.takeUnretainedValue() as? NSObject else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let selector = NSSelectorFromString("loadConfigurationsWithCompletionQueue:handler:")
        guard manager.responds(to: selector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let handler: @convention(block) (NSArray?, NSError?) -> Void = { configurations, error in
            Task { @MainActor in
                if let error = error {
                    completion(.failure(.frameworkLoadFailed(reason: error.localizedDescription)))
                    return
                }
                
                guard let nsArray = configurations as NSArray? else {
                    completion(.success([]))
                    return
                }
                
                let connections = self.processConfigurations(nsArray)
                completion(.success(connections))
            }
        }
        
        guard let imp = manager.method(for: selector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let block = unsafeBitCast(handler, to: AnyObject.self)
        let queue = self.sessionQueue
        
        typealias MethodType = @convention(c) (AnyObject, Selector, DispatchQueue, AnyObject) -> Void
        let method = unsafeBitCast(imp, to: MethodType.self)
        
        method(manager, selector, queue, block)
    }
    
    private func loadConfigurationsAlternative(completion: @escaping (Result<[VPNConnection], VPNError>) -> Void) {
        let frameworkPath = "/System/Library/Frameworks/NetworkExtension.framework/NetworkExtension"
        guard let framework = dlopen(frameworkPath, RTLD_LAZY) else {
            let error = String(cString: dlerror())
            completion(.failure(.frameworkLoadFailed(reason: error)))
            return
        }
        
        defer { dlclose(framework) }
        
        guard let managerClass = NSClassFromString("NEConfigurationManager") as? NSObject.Type else {
            if objc_getClass("NEConfigurationManager") != nil {
                loadConfigurations(completion: completion)
            } else {
                completion(.success([]))
            }
            return
        }
        
        loadConfigurationsWithManagerClass(managerClass, completion: completion)
    }
    
    private func loadConfigurationsWithManagerClass(_ managerType: NSObject.Type, completion: @escaping (Result<[VPNConnection], VPNError>) -> Void) {
        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard managerType.responds(to: sharedManagerSelector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let sharedManagerResult = managerType.perform(sharedManagerSelector)
        guard let manager = sharedManagerResult?.takeUnretainedValue() as? NSObject else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let selector = NSSelectorFromString("loadConfigurationsWithCompletionQueue:handler:")
        guard manager.responds(to: selector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let handler: @convention(block) (NSArray?, NSError?) -> Void = { configurations, error in
            Task { @MainActor in
                if let error = error {
                    completion(.failure(.frameworkLoadFailed(reason: error.localizedDescription)))
                    return
                }
                
                guard let nsArray = configurations as NSArray? else {
                    completion(.success([]))
                    return
                }
                
                let connections = self.processConfigurations(nsArray)
                completion(.success(connections))
            }
        }
        
        guard let imp = manager.method(for: selector) else {
            completion(.failure(.sharedManagerUnavailable))
            return
        }
        
        let block = unsafeBitCast(handler, to: AnyObject.self)
        let queue = self.sessionQueue
        
        typealias MethodType = @convention(c) (AnyObject, Selector, DispatchQueue, AnyObject) -> Void
        let method = unsafeBitCast(imp, to: MethodType.self)
        
        method(manager, selector, queue, block)
    }
    
    private func processConfigurations(_ configurations: NSArray) -> [VPNConnection] {
        var processedConnections: [VPNConnection] = []
        
        for index in 0..<configurations.count {
            guard let config = configurations[index] as? NSObject else {
                continue
            }
            
            let name = config.value(forKey: "name") as? String
            let identifier = config.value(forKey: "identifier") as? NSUUID
            
            guard let name = name, let identifier = identifier,
                  !name.hasPrefix("com.apple.preferences.") else {
                continue
            }
            
            let identifierString = identifier.uuidString
            
            processedConnections.append(VPNConnection(
                id: identifierString,
                name: name,
                serviceID: identifierString,
                status: .disconnected
            ))
        }
        
        return processedConnections.sorted { $0.name < $1.name }
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
}


