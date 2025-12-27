import XCTest
@testable import VPNBarApp

@MainActor
final class ConnectionHistoryPerformanceTests: XCTestCase {
    var sut: ConnectionHistoryManager!
    
    override func setUp() {
        super.setUp()
        sut = ConnectionHistoryManager.shared
        sut.clearHistory()
    }
    
    override func tearDown() {
        sut.clearHistory()
        super.tearDown()
    }
    
    func test_addEntry_performance() {
        measure {
            for i in 0..<100 {
                sut.addEntry(connectionID: "id-\(i)", connectionName: "VPN \(i)", action: .connected)
            }
        }
    }
    
    func test_getHistory_performance() {
        for i in 0..<100 {
            sut.addEntry(connectionID: "id-\(i)", connectionName: "VPN \(i)", action: .connected)
        }
        
        measure {
            _ = sut.getHistory(limit: 50)
        }
    }
    
    func test_historySorting_performance() {
        for i in 0..<1000 {
            sut.addEntry(connectionID: "id-\(i)", connectionName: "VPN \(i)", action: .connected)
        }
        
        measure {
            _ = sut.getHistory(limit: 100)
        }
    }
}


