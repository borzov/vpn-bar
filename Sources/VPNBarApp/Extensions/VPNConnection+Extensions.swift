import Foundation

extension VPNConnection.VPNStatus {
    var localizedDescription: String {
        switch self {
        case .connected:
            return NSLocalizedString("menu.status.connected", comment: "Status label: connected")
        case .connecting:
            return NSLocalizedString("menu.status.connecting", comment: "Status label: connecting")
        case .disconnecting:
            return NSLocalizedString("menu.status.disconnecting", comment: "Status label: disconnecting")
        case .disconnected:
            return NSLocalizedString("menu.status.disconnected", comment: "Status label: disconnected")
        }
    }
}


