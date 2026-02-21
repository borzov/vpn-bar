import Foundation

/// Public IP and geolocation information.
struct NetworkInfo: Equatable {
    let publicIP: String?
    let country: String?
    let countryCode: String?
    let city: String?
    let vpnInterfaces: [VPNInterface]
    let lastUpdated: Date

    /// Country flag emoji derived from country code (e.g., "US" -> flag).
    var countryFlag: String? {
        guard let code = countryCode, code.count == 2 else { return nil }
        let base: UInt32 = 127397
        var flag = ""
        for scalar in code.uppercased().unicodeScalars {
            guard let flagScalar = Unicode.Scalar(base + scalar.value) else { return nil }
            flag.append(String(flagScalar))
        }
        return flag
    }

    /// Formatted location string (e.g., "flag Country, City").
    var formattedLocation: String? {
        guard let country = country else { return nil }
        var parts: [String] = []
        if let flag = countryFlag {
            parts.append(flag)
        }
        if let city = city {
            parts.append("\(country), \(city)")
        } else {
            parts.append(country)
        }
        return parts.joined(separator: " ")
    }
}

/// VPN network interface information.
struct VPNInterface: Equatable {
    let name: String
    let address: String
}
