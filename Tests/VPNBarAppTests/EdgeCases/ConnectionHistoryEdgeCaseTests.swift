import XCTest
@testable import VPNBarApp

@MainActor
final class ConnectionHistoryEdgeCaseTests: XCTestCase {
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
    
    func test_veryLongConnectionName_isStoredCorrectly() {
        let longName = String(repeating: "A", count: 10000)
        sut.addEntry(connectionID: "test-id", connectionName: longName, action: .connected)
        
        let history = sut.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.connectionName, longName)
    }
    
    func test_specialCharactersInConnectionName_isStoredCorrectly() {
        let specialName = "VPN!@#$%^&*()_+-=[]{}|;':\",./<>?~`"
        sut.addEntry(connectionID: "test-id", connectionName: specialName, action: .connected)
        
        let history = sut.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.connectionName, specialName)
    }
    
    func test_unicodeCharactersInConnectionName_isStoredCorrectly() {
        let unicodeName = "VPN名称🚀🔒测试"
        sut.addEntry(connectionID: "test-id", connectionName: unicodeName, action: .connected)
        
        let history = sut.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.connectionName, unicodeName)
    }
    
    func test_emptyConnectionName_isStoredCorrectly() {
        sut.addEntry(connectionID: "test-id", connectionName: "", action: .connected)
        
        let history = sut.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.connectionName, "")
    }
    
    func test_maxHistoryEntries_limitIsEnforced() {
        for i in 0..<150 {
            sut.addEntry(connectionID: "id-\(i)", connectionName: "VPN \(i)", action: .connected)
        }
        
        let history = sut.getHistory(limit: 200)
        XCTAssertLessThanOrEqual(history.count, 100, "History should be limited to max entries")
    }
    
    func test_historySorting_newestFirst() {
        for i in 0..<10 {
            sut.addEntry(connectionID: "id-\(i)", connectionName: "VPN \(i)", action: .connected)
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let history = sut.getHistory()
        XCTAssertGreaterThan(history.count, 0)
        
        for i in 0..<history.count - 1 {
            XCTAssertGreaterThanOrEqual(
                history[i].timestamp,
                history[i + 1].timestamp,
                "History should be sorted newest first"
            )
        }
    }
}


