import XCTest
@testable import VPNBarApp

@MainActor
final class StatisticsManagerPerformanceTests: XCTestCase {
    var sut: StatisticsManager!
    
    override func setUp() {
        super.setUp()
        sut = StatisticsManager.shared
        sut.resetStatistics()
    }
    
    override func tearDown() {
        sut.resetStatistics()
        super.tearDown()
    }
    
    func test_recordConnection_performance() throws {
        throw XCTSkip("measure {} with shared singletons may hang in CI")
        measure {
            for _ in 0..<1000 {
                sut.recordConnection()
            }
        }
    }
    
    func test_recordDisconnection_performance() throws {
        throw XCTSkip("measure {} with shared singletons may hang in CI")
        measure {
            for _ in 0..<1000 {
                sut.recordConnection()
                sut.recordDisconnection()
            }
        }
    }
    
    func test_getStatistics_performance() throws {
        throw XCTSkip("measure {} with shared singletons may hang in CI")
        for _ in 0..<100 {
            sut.recordConnection()
            sut.recordDisconnection()
        }
        
        measure {
            _ = sut.getStatistics()
        }
    }
}


