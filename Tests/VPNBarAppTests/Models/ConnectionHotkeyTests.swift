import XCTest
@testable import VPNBarApp

final class ConnectionHotkeyTests: XCTestCase {
    func test_init_setsProperties() {
        let hotkey = ConnectionHotkey(connectionID: "abc-123", keyCode: 0, modifiers: 256)

        XCTAssertEqual(hotkey.connectionID, "abc-123")
        XCTAssertEqual(hotkey.keyCode, 0)
        XCTAssertEqual(hotkey.modifiers, 256)
    }

    func test_id_returnsConnectionID() {
        let hotkey = ConnectionHotkey(connectionID: "test-id", keyCode: 1, modifiers: 2)
        XCTAssertEqual(hotkey.id, "test-id")
    }

    func test_equatable_sameValues_areEqual() {
        let a = ConnectionHotkey(connectionID: "id", keyCode: 10, modifiers: 20)
        let b = ConnectionHotkey(connectionID: "id", keyCode: 10, modifiers: 20)
        XCTAssertEqual(a, b)
    }

    func test_equatable_differentValues_areNotEqual() {
        let a = ConnectionHotkey(connectionID: "id1", keyCode: 10, modifiers: 20)
        let b = ConnectionHotkey(connectionID: "id2", keyCode: 10, modifiers: 20)
        XCTAssertNotEqual(a, b)
    }

    func test_codable_roundTrip() throws {
        let original = ConnectionHotkey(connectionID: "uuid-123", keyCode: 45, modifiers: 768)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConnectionHotkey.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_codable_array_roundTrip() throws {
        let originals = [
            ConnectionHotkey(connectionID: "a", keyCode: 1, modifiers: 2),
            ConnectionHotkey(connectionID: "b", keyCode: 3, modifiers: 4)
        ]
        let data = try JSONEncoder().encode(originals)
        let decoded = try JSONDecoder().decode([ConnectionHotkey].self, from: data)
        XCTAssertEqual(originals, decoded)
    }
}
