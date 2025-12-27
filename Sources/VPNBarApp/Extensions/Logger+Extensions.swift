import os.log

extension Logger {
    static let vpn = Logger(subsystem: AppConstants.bundleIdentifier, category: "VPN")
    static let settings = Logger(subsystem: AppConstants.bundleIdentifier, category: "Settings")
    static let hotkey = Logger(subsystem: AppConstants.bundleIdentifier, category: "Hotkey")
}


