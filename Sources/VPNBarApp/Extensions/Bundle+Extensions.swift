import Foundation

extension Bundle {
    var appName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "VPN Bar"
    }

    var formattedVersion: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }
}


