import XCTest
@testable import VPNBarApp

final class VPNStatisticsTests: XCTestCase {

    // MARK: - VPNStatistics Structure Tests

    func test_init_defaultValues() {
        let stats = VPNStatistics()

        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.totalDisconnections, 0)
        XCTAssertEqual(stats.totalConnectionTime, 0)
        XCTAssertNil(stats.lastConnectionDate)
        XCTAssertNil(stats.lastDisconnectionDate)
        XCTAssertEqual(stats.longestSessionDuration, 0)
        XCTAssertNil(stats.shortestSessionDuration)
    }

    func test_averageSessionDuration_withZeroConnections_returnsZero() {
        let stats = VPNStatistics()
        XCTAssertEqual(stats.averageSessionDuration, 0)
    }

    func test_averageSessionDuration_withConnections_calculatesCorrectly() {
        var stats = VPNStatistics()
        stats.totalConnections = 4
        stats.totalConnectionTime = 100

        XCTAssertEqual(stats.averageSessionDuration, 25)
    }

    func test_averageSessionDuration_withSingleConnection() {
        var stats = VPNStatistics()
        stats.totalConnections = 1
        stats.totalConnectionTime = 60

        XCTAssertEqual(stats.averageSessionDuration, 60)
    }

    func test_equatable_sameValues_areEqual() {
        let date = Date()
        var stats1 = VPNStatistics()
        stats1.totalConnections = 5
        stats1.totalDisconnections = 4
        stats1.totalConnectionTime = 100
        stats1.lastConnectionDate = date
        stats1.longestSessionDuration = 50
        stats1.shortestSessionDuration = 10

        var stats2 = VPNStatistics()
        stats2.totalConnections = 5
        stats2.totalDisconnections = 4
        stats2.totalConnectionTime = 100
        stats2.lastConnectionDate = date
        stats2.longestSessionDuration = 50
        stats2.shortestSessionDuration = 10

        XCTAssertEqual(stats1, stats2)
    }

    func test_equatable_differentValues_areNotEqual() {
        var stats1 = VPNStatistics()
        stats1.totalConnections = 5

        var stats2 = VPNStatistics()
        stats2.totalConnections = 10

        XCTAssertNotEqual(stats1, stats2)
    }

    func test_codable_encodeDecode_preservesValues() throws {
        var original = VPNStatistics()
        original.totalConnections = 10
        original.totalDisconnections = 8
        original.totalConnectionTime = 3600
        original.lastConnectionDate = Date(timeIntervalSince1970: 1000000)
        original.lastDisconnectionDate = Date(timeIntervalSince1970: 1000100)
        original.longestSessionDuration = 1200
        original.shortestSessionDuration = 60

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VPNStatistics.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func test_codable_withNilDates_encodesCorrectly() throws {
        let original = VPNStatistics()

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VPNStatistics.self, from: data)

        XCTAssertNil(decoded.lastConnectionDate)
        XCTAssertNil(decoded.lastDisconnectionDate)
        XCTAssertNil(decoded.shortestSessionDuration)
    }
}

// MARK: - StatisticsManager Tests

@MainActor
final class StatisticsManagerTests: XCTestCase {
    var sut: StatisticsManager!

    override func setUp() {
        super.setUp()
        sut = StatisticsManager.shared
        sut.resetStatistics()
    }

    override func tearDown() {
        sut.resetStatistics()
        sut = nil
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func test_shared_isSingleton() {
        let instance1 = StatisticsManager.shared
        let instance2 = StatisticsManager.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Initial State Tests

    func test_getStatistics_afterReset_returnsDefaultValues() {
        sut.resetStatistics()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.totalDisconnections, 0)
        XCTAssertEqual(stats.totalConnectionTime, 0)
    }

    // MARK: - Record Connection Tests

    func test_recordConnection_incrementsTotalConnections() {
        sut.recordConnection()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalConnections, 1)
    }

    func test_recordConnection_setsLastConnectionDate() {
        let beforeDate = Date()

        sut.recordConnection()

        let stats = sut.getStatistics()
        let afterDate = Date()

        XCTAssertNotNil(stats.lastConnectionDate)
        if let connectionDate = stats.lastConnectionDate {
            XCTAssertGreaterThanOrEqual(connectionDate, beforeDate)
            XCTAssertLessThanOrEqual(connectionDate, afterDate)
        }
    }

    func test_recordConnection_multipleTimes_incrementsCorrectly() {
        sut.recordConnection()
        sut.recordConnection()
        sut.recordConnection()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalConnections, 3)
    }

    // MARK: - Record Disconnection Tests

    func test_recordDisconnection_withoutPriorConnection_doesNothing() {
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalDisconnections, 0)
    }

    func test_recordDisconnection_afterConnection_incrementsDisconnections() {
        sut.recordConnection()
        // Small delay to ensure some duration
        Thread.sleep(forTimeInterval: 0.01)
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalDisconnections, 1)
    }

    func test_recordDisconnection_setsLastDisconnectionDate() {
        sut.recordConnection()

        let beforeDate = Date()
        sut.recordDisconnection()
        let afterDate = Date()

        let stats = sut.getStatistics()

        XCTAssertNotNil(stats.lastDisconnectionDate)
        if let disconnectionDate = stats.lastDisconnectionDate {
            XCTAssertGreaterThanOrEqual(disconnectionDate, beforeDate)
            XCTAssertLessThanOrEqual(disconnectionDate, afterDate)
        }
    }

    func test_recordDisconnection_addsTotalConnectionTime() {
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05) // 50ms
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        XCTAssertGreaterThan(stats.totalConnectionTime, 0)
    }

    func test_recordDisconnection_updatesLongestSessionDuration() {
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05)
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        XCTAssertGreaterThan(stats.longestSessionDuration, 0)
    }

    func test_recordDisconnection_updatesShortestSessionDuration() {
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.01)
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        XCTAssertNotNil(stats.shortestSessionDuration)
        XCTAssertGreaterThan(stats.shortestSessionDuration ?? 0, 0)
    }

    // MARK: - Session Duration Tracking Tests

    func test_multipleConnections_trackLongestCorrectly() {
        // First short session
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.01)
        sut.recordDisconnection()

        let statsAfterFirst = sut.getStatistics()
        let firstDuration = statsAfterFirst.longestSessionDuration

        // Second longer session
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05)
        sut.recordDisconnection()

        let statsAfterSecond = sut.getStatistics()

        XCTAssertGreaterThan(statsAfterSecond.longestSessionDuration, firstDuration)
    }

    func test_multipleConnections_trackShortestCorrectly() {
        // First longer session
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05)
        sut.recordDisconnection()

        let statsAfterFirst = sut.getStatistics()
        let firstShortest = statsAfterFirst.shortestSessionDuration

        // Second shorter session
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.01)
        sut.recordDisconnection()

        let statsAfterSecond = sut.getStatistics()

        // Shortest should be the second (shorter) session
        XCTAssertNotNil(statsAfterSecond.shortestSessionDuration)
        XCTAssertLessThan(statsAfterSecond.shortestSessionDuration!, firstShortest!)
    }

    // MARK: - Reset Statistics Tests

    func test_resetStatistics_clearsAllValues() {
        sut.recordConnection()
        sut.recordDisconnection()

        sut.resetStatistics()

        let stats = sut.getStatistics()

        XCTAssertEqual(stats.totalConnections, 0)
        XCTAssertEqual(stats.totalDisconnections, 0)
        XCTAssertEqual(stats.totalConnectionTime, 0)
        XCTAssertNil(stats.lastConnectionDate)
        XCTAssertNil(stats.lastDisconnectionDate)
        XCTAssertEqual(stats.longestSessionDuration, 0)
        XCTAssertNil(stats.shortestSessionDuration)
    }

    // MARK: - Average Duration Tests

    func test_averageSessionDuration_calculatesCorrectly() {
        // Two sessions with ~50ms each
        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05)
        sut.recordDisconnection()

        sut.recordConnection()
        Thread.sleep(forTimeInterval: 0.05)
        sut.recordDisconnection()

        let stats = sut.getStatistics()

        // Average should be approximately 50ms (0.05s)
        // Allow some tolerance for timing variations
        XCTAssertGreaterThan(stats.averageSessionDuration, 0.01)
        XCTAssertLessThan(stats.averageSessionDuration, 0.2)
    }
}
