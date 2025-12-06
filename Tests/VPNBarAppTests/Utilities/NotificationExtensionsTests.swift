import XCTest
@testable import VPNBarApp

final class NotificationExtensionsTests: XCTestCase {
    
    func test_hotkeyDidChange_isDefined() {
        let name = Notification.Name.hotkeyDidChange
        
        XCTAssertEqual(name.rawValue, "HotkeyDidChange")
    }
    
    func test_updateIntervalDidChange_isDefined() {
        let name = Notification.Name.updateIntervalDidChange
        
        XCTAssertEqual(name.rawValue, "UpdateIntervalDidChange")
    }
    
    func test_showConnectionNameDidChange_isDefined() {
        let name = Notification.Name.showConnectionNameDidChange
        
        XCTAssertEqual(name.rawValue, "ShowConnectionNameDidChange")
    }
    
    func test_showNotificationsDidChange_isDefined() {
        let name = Notification.Name.showNotificationsDidChange
        
        XCTAssertEqual(name.rawValue, "ShowNotificationsDidChange")
    }
    
    func test_vpnStatusDidChange_isDefined() {
        let name = Notification.Name.vpnStatusDidChange
        
        XCTAssertEqual(name.rawValue, "VPNStatusDidChange")
    }
    
    func test_vpnConnectionsDidLoad_isDefined() {
        let name = Notification.Name.vpnConnectionsDidLoad
        
        XCTAssertEqual(name.rawValue, "VPNConnectionsDidLoad")
    }
    
    func test_allNotificationNames_areUnique() {
        let names = [
            Notification.Name.hotkeyDidChange,
            Notification.Name.updateIntervalDidChange,
            Notification.Name.showConnectionNameDidChange,
            Notification.Name.showNotificationsDidChange,
            Notification.Name.vpnStatusDidChange,
            Notification.Name.vpnConnectionsDidLoad
        ]
        
        let rawValues = names.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        
        XCTAssertEqual(rawValues.count, uniqueValues.count, "All notification names should be unique")
    }
}

