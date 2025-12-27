import XCTest
@testable import VPNBarApp

final class KeyCodeTests: XCTestCase {
    
    func test_escape_hasCorrectRawValue() {
        XCTAssertEqual(KeyCode.escape.rawValue, 53)
    }
    
    func test_escape_hasCorrectStringValue() {
        XCTAssertEqual(KeyCode.escape.stringValue, "⎋")
    }
    
    func test_letterKeys_haveCorrectStringValues() {
        XCTAssertEqual(KeyCode.a.stringValue, "A")
        XCTAssertEqual(KeyCode.z.stringValue, "Z")
        XCTAssertEqual(KeyCode.q.stringValue, "Q")
    }
    
    func test_numberKeys_haveCorrectStringValues() {
        XCTAssertEqual(KeyCode.one.stringValue, "1")
        XCTAssertEqual(KeyCode.zero.stringValue, "0")
    }
    
    func test_specialKeys_haveCorrectStringValues() {
        XCTAssertEqual(KeyCode.returnKey.stringValue, "↩")
        XCTAssertEqual(KeyCode.tab.stringValue, "⇥")
        XCTAssertEqual(KeyCode.space.stringValue, "␣")
        XCTAssertEqual(KeyCode.delete.stringValue, "⌫")
    }
    
    func test_initFromRawValue_returnsCorrectKey() {
        XCTAssertEqual(KeyCode(rawValue: 0), .a)
        XCTAssertEqual(KeyCode(rawValue: 53), .escape)
        XCTAssertEqual(KeyCode(rawValue: 36), .returnKey)
    }
    
    func test_initFromRawValue_withInvalidValue_returnsNil() {
        XCTAssertNil(KeyCode(rawValue: 999))
    }
    
    func test_initFromUInt32_createsKeyCode() {
        let keyCode = KeyCode(53)
        XCTAssertEqual(keyCode, .escape)
    }
    
    func test_initFromUInt32_withInvalidValue_returnsDefault() {
        let keyCode = KeyCode(999)
        XCTAssertEqual(keyCode, .a)
    }
}


