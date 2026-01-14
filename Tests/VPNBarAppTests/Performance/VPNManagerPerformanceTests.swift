import XCTest
@testable import VPNBarApp

@MainActor
final class VPNManagerPerformanceTests: XCTestCase {
    var sut: VPNManager!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_loadConnections_performance() throws {
        throw XCTSkip("VPNManager.shared initializes system APIs which may hang in CI")
    }
    
    func test_processConfigurations_performance() throws {
        throw XCTSkip("VPNManager.shared initializes system APIs which may hang in CI")
    }
    
    func test_updateConnectionStatus_performance() throws {
        throw XCTSkip("VPNManager.shared initializes system APIs which may hang in CI")
    }
    
    func test_refreshAllStatuses_performance() throws {
        throw XCTSkip("VPNManager.shared initializes system APIs which may hang in CI")
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


