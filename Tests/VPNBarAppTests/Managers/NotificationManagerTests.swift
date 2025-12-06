import XCTest
@testable import VPNBarApp

@MainActor
final class NotificationManagerTests: XCTestCase {
    var sut: NotificationManager!
    
    override func setUp() {
        super.setUp()
        sut = NotificationManager.shared
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func test_shared_isSingleton() {
        let instance1 = NotificationManager.shared
        let instance2 = NotificationManager.shared
        
        XCTAssertTrue(instance1 === instance2)
    }
    
    func test_isAuthorized_initiallyFalse() {
        XCTAssertFalse(sut.isAuthorized)
    }
    
    func test_requestAuthorization_canBeCalled() {
        sut.requestAuthorization()
        
        XCTAssertTrue(true)
    }
    
    func test_checkAuthorizationStatus_canBeCalled() {
        sut.checkAuthorizationStatus()
        
        XCTAssertTrue(true)
    }
    
    func test_sendVPNNotification_withConnectedState_canBeCalled() {
        sut.sendVPNNotification(isConnected: true, connectionName: "Test VPN")
        
        XCTAssertTrue(true)
    }
    
    func test_sendVPNNotification_withDisconnectedState_canBeCalled() {
        sut.sendVPNNotification(isConnected: false, connectionName: "Test VPN")
        
        XCTAssertTrue(true)
    }
    
    func test_sendVPNNotification_withNilConnectionName_canBeCalled() {
        sut.sendVPNNotification(isConnected: true, connectionName: nil)
        
        XCTAssertTrue(true)
    }
    
    func test_removeAllDeliveredNotifications_canBeCalled() {
        sut.removeAllDeliveredNotifications()
        
        XCTAssertTrue(true)
    }
}

