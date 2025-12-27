import XCTest
@testable import VPNBarApp

final class ComparableExtensionsTests: XCTestCase {
    
    func test_clamped_withinRange_returnsOriginalValue() {
        let value = 5.0
        let range = 0.0...10.0
        
        XCTAssertEqual(value.clamped(to: range), 5.0)
    }
    
    func test_clamped_belowRange_returnsLowerBound() {
        let value = -5.0
        let range = 0.0...10.0
        
        XCTAssertEqual(value.clamped(to: range), 0.0)
    }
    
    func test_clamped_aboveRange_returnsUpperBound() {
        let value = 15.0
        let range = 0.0...10.0
        
        XCTAssertEqual(value.clamped(to: range), 10.0)
    }
    
    func test_clamped_atLowerBound_returnsLowerBound() {
        let value = 0.0
        let range = 0.0...10.0
        
        XCTAssertEqual(value.clamped(to: range), 0.0)
    }
    
    func test_clamped_atUpperBound_returnsUpperBound() {
        let value = 10.0
        let range = 0.0...10.0
        
        XCTAssertEqual(value.clamped(to: range), 10.0)
    }
    
    func test_clamped_withInt_worksCorrectly() {
        let value = 15
        let range = 5...10
        
        XCTAssertEqual(value.clamped(to: range), 10)
    }
}


