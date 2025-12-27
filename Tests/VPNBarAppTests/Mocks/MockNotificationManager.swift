import Foundation
@testable import VPNBarApp

@MainActor
final class MockNotificationManager {
    var isAuthorized: Bool = false
    
    var requestAuthorizationCalled = false
    var checkAuthorizationStatusCalled = false
    var sendVPNNotificationCalled = false
    var sendVPNNotificationIsConnected: Bool?
    var sendVPNNotificationConnectionName: String?
    var removeAllDeliveredNotificationsCalled = false
    
    var requestAuthorizationResult: Bool = true
    var checkAuthorizationStatusResult: Bool = true
    var sendVPNNotificationShouldSucceed = true
    
    func requestAuthorization() {
        requestAuthorizationCalled = true
        isAuthorized = requestAuthorizationResult
    }
    
    func checkAuthorizationStatus() {
        checkAuthorizationStatusCalled = true
        isAuthorized = checkAuthorizationStatusResult
    }
    
    func sendVPNNotification(isConnected: Bool, connectionName: String?) {
        sendVPNNotificationCalled = true
        sendVPNNotificationIsConnected = isConnected
        sendVPNNotificationConnectionName = connectionName
    }
    
    func removeAllDeliveredNotifications() {
        removeAllDeliveredNotificationsCalled = true
    }
    
    func reset() {
        isAuthorized = false
        requestAuthorizationCalled = false
        checkAuthorizationStatusCalled = false
        sendVPNNotificationCalled = false
        sendVPNNotificationIsConnected = nil
        sendVPNNotificationConnectionName = nil
        removeAllDeliveredNotificationsCalled = false
        requestAuthorizationResult = true
        checkAuthorizationStatusResult = true
        sendVPNNotificationShouldSucceed = true
    }
}


