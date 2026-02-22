import Foundation
import os.log
import Darwin
import SystemConfiguration

/// Manages network information: public IP, geolocation, and VPN interfaces.
@MainActor
final class NetworkInfoManager: NetworkInfoManagerProtocol {
    static let shared = NetworkInfoManager()

    @Published var networkInfo: NetworkInfo?

    private var lastFetchDate: Date?
    private var fetchTask: Task<Void, Never>?
    private var statusObserverToken: NSObjectProtocol?
    private var isFetching = false

    private init() {
        observeVPNStatusChanges()
    }

    func refresh(force: Bool = false) {
        guard !isFetching else { return }

        if !force, let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < AppConstants.networkInfoCacheDuration {
            return
        }

        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            await fetchNetworkInfo()
        }
    }

    func cleanup() {
        fetchTask?.cancel()
        fetchTask = nil
        isFetching = false
        if let token = statusObserverToken {
            NotificationCenter.default.removeObserver(token)
            statusObserverToken = nil
        }
    }

    private func observeVPNStatusChanges() {
        statusObserverToken = NotificationCenter.default.addObserver(
            forName: .vpnConnectionStatusDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                if let status = notification.userInfo?["status"] as? SCNetworkConnectionStatus,
                   status == .disconnected || status == .invalid {
                    self.networkInfo = nil
                    self.lastFetchDate = nil
                }
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.networkInfoRefreshDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.refresh(force: true)
            }
        }
    }

    private func fetchNetworkInfo() async {
        defer { isFetching = false }

        guard !Task.isCancelled else { return }

        isFetching = true
        let vpnInterfaces = detectVPNInterfaces()
        let geoInfo = await fetchGeoIP()

        guard !Task.isCancelled else { return }

        if let geo = geoInfo {
            let info = NetworkInfo(
                publicIP: geo.ip,
                country: geo.country,
                countryCode: geo.countryCode,
                city: geo.city,
                vpnInterfaces: vpnInterfaces,
                lastUpdated: Date()
            )
            networkInfo = info
            lastFetchDate = Date()
        } else {
            networkInfo = nil
        }
    }

    // MARK: - GeoIP

    private struct GeoIPResponse: Decodable {
        let status: String?
        let country: String?
        let countryCode: String?
        let city: String?
        let query: String?
    }

    private struct GeoInfo {
        let ip: String?
        let country: String?
        let countryCode: String?
        let city: String?
    }

    private func fetchGeoIP() async -> GeoInfo? {
        do {
            var request = URLRequest(url: AppConstants.NetworkInfo.geoIPURL)
            request.timeoutInterval = AppConstants.NetworkInfo.requestTimeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(GeoIPResponse.self, from: data)
            guard decoded.status == "success" else {
                return nil
            }

            let geoInfo = GeoInfo(
                ip: decoded.query,
                country: decoded.country,
                countryCode: decoded.countryCode,
                city: decoded.city
            )
            let hasAnyGeoData = geoInfo.ip != nil || geoInfo.country != nil || geoInfo.countryCode != nil || geoInfo.city != nil
            return hasAnyGeoData ? geoInfo : nil
        } catch {
            Logger.vpn.warning("GeoIP fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - VPN Interface Detection

    private static let vpnInterfacePrefixes = ["utun", "ppp", "ipsec", "tap", "tun", "gpd", "wg"]

    private func detectVPNInterfaces() -> [VPNInterface] {
        var interfaces: [VPNInterface] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return interfaces
        }
        defer { freeifaddrs(ifaddr) }

        var currentAddr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = currentAddr {
            let flags = Int32(addr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0

            if isUp && isRunning,
               addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: addr.pointee.ifa_name)

                if Self.vpnInterfacePrefixes.contains(where: { name.hasPrefix($0) }) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(
                        addr.pointee.ifa_addr,
                        socklen_t(addr.pointee.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil, 0,
                        NI_NUMERICHOST
                    ) == 0 {
                        let address = String(cString: hostname)
                        interfaces.append(VPNInterface(name: name, address: address))
                    }
                }
            }
            currentAddr = addr.pointee.ifa_next
        }

        return interfaces
    }
}
