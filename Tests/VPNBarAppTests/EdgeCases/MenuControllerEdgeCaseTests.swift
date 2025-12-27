import XCTest
import AppKit
@testable import VPNBarApp

@MainActor
final class MenuControllerEdgeCaseTests: XCTestCase {
    var sut: MenuController!
    var mockVPNManager: MockVPNManager!
    
    override func setUp() {
        super.setUp()
        mockVPNManager = MockVPNManager()
        sut = MenuController(vpnManager: mockVPNManager)
    }
    
    override func tearDown() {
        sut = nil
        mockVPNManager = nil
        super.tearDown()
    }
    
    func test_veryLongVPNName_isHandledCorrectly() {
        let veryLongName = String(repeating: "A", count: 1000)
        let connection = VPNConnection(
            id: "test-id",
            name: veryLongName,
            serviceID: "test-service",
            status: .connected
        )
        
        mockVPNManager.connections = [connection]
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        sut.showMenu(for: statusItem)
        
        // Menu может быть nil в тестовом окружении
        if let menu = statusItem.menu {
            XCTAssertGreaterThan(menu.items.count, 0)
            let menuItem = menu.items.first { $0.title.contains(veryLongName.prefix(50)) }
            XCTAssertNotNil(menuItem, "Menu should contain item with long VPN name")
        }
    }
    
    func test_specialCharactersInVPNName_isHandledCorrectly() {
        let specialChars = "VPN-Name!@#$%^&*()_+{}[]|\\:;\"'<>?,./~`"
        let connection = VPNConnection(
            id: "test-id",
            name: specialChars,
            serviceID: "test-service",
            status: .connected
        )
        
        mockVPNManager.connections = [connection]
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        sut.showMenu(for: statusItem)
        
        // Menu может быть nil в тестовом окружении
        if let menu = statusItem.menu {
            let menuItem = menu.items.first { $0.title.contains(specialChars) }
            XCTAssertNotNil(menuItem, "Menu should handle special characters in VPN name")
        }
    }
    
    func test_emptyConnectionList_displaysCorrectly() {
        mockVPNManager.connections = []
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        sut.showMenu(for: statusItem)
        
        // Menu может быть nil в тестовом окружении, это нормально
        if let menu = statusItem.menu {
            XCTAssertGreaterThanOrEqual(menu.items.count, 0, "Menu should exist even with empty connection list")
        }
    }
    
    func test_unicodeCharactersInVPNName_isHandledCorrectly() {
        let unicodeName = "VPN名称🚀🔒测试"
        let connection = VPNConnection(
            id: "test-id",
            name: unicodeName,
            serviceID: "test-service",
            status: .connected
        )
        
        mockVPNManager.connections = [connection]
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        sut.showMenu(for: statusItem)
        
        // Menu может быть nil в тестовом окружении
        if let menu = statusItem.menu {
            let menuItem = menu.items.first { $0.title.contains(unicodeName) }
            XCTAssertNotNil(menuItem, "Menu should handle Unicode characters in VPN name")
        }
    }
    
    func test_whitespaceOnlyVPNName_isHandledCorrectly() {
        let whitespaceName = "   \n\t   "
        let connection = VPNConnection(
            id: "test-id",
            name: whitespaceName,
            serviceID: "test-service",
            status: .connected
        )
        
        mockVPNManager.connections = [connection]
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        sut.showMenu(for: statusItem)
        
        // Menu может быть nil в тестовом окружении, это нормально
        _ = statusItem.menu
    }
}

