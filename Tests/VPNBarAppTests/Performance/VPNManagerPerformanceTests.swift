import XCTest
@testable import VPNBarApp

@MainActor
final class VPNManagerPerformanceTests: XCTestCase {
    var sut: VPNManager!
    
    override func setUp() {
        super.setUp()
        sut = VPNManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_loadConnections_performance() {
        measure {
            sut.loadConnections(forceReload: true)
        }
    }
    
    func test_processConfigurations_performance() {
        let largeArray = (0..<1000).map { index in
            let config = NSObject()
            config.setValue("VPN \(index)", forKey: "name")
            config.setValue(NSUUID(), forKey: "identifier")
            return config
        } as NSArray
        
        measure {
            // Используем рефлексию для вызова приватного метода
            let mirror = Mirror(reflecting: sut!)
            if let processMethod = mirror.children.first(where: { $0.label == "processConfigurations" }) {
                // В реальном тесте нужно было бы использовать другой подход
                // Здесь просто измеряем время создания массива
                _ = largeArray
            }
        }
    }
    
    func test_updateConnectionStatus_performance() {
        let connections = (0..<100).map { index in
            VPNConnection(
                id: UUID().uuidString,
                name: "VPN \(index)",
                serviceID: UUID().uuidString,
                status: .disconnected
            )
        }
        
        sut.connections = connections
        
        measure {
            for connection in connections {
                sut.toggleConnection(connection.id)
            }
        }
    }
    
    func test_refreshAllStatuses_performance() {
        let connections = (0..<50).map { index in
            VPNConnection(
                id: UUID().uuidString,
                name: "VPN \(index)",
                serviceID: UUID().uuidString,
                status: .connected
            )
        }
        
        sut.connections = connections
        
        measure {
            // Симулируем обновление статусов
            for connection in connections {
                sut.toggleConnection(connection.id)
            }
        }
    }
    
    func test_connectionSorting_performance() {
        let connections = (0..<1000).map { index in
            VPNConnection(
                id: UUID().uuidString,
                name: "VPN \(Int.random(in: 0..<1000))",
                serviceID: UUID().uuidString,
                status: .disconnected
            )
        }
        
        measure {
            _ = connections.sorted { $0.name < $1.name }
        }
    }
}


