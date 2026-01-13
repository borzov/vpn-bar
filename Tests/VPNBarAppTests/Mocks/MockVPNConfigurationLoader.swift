import Foundation
@testable import VPNBarApp

@MainActor
final class MockVPNConfigurationLoader: VPNConfigurationLoaderProtocol {
    var connectionsToReturn: [VPNConnection] = []
    var errorToReturn: VPNError?
    var loadConfigurationsCalled = false
    var delay: TimeInterval = 0
    var completionDelay: TimeInterval = 0

    func loadConfigurations(completion: @escaping (Result<[VPNConnection], VPNError>) -> Void) {
        loadConfigurationsCalled = true

        let delayToUse = completionDelay > 0 ? completionDelay : delay
        
        if delayToUse > 0 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delayToUse * 1_000_000_000))
                if let error = errorToReturn {
                    completion(.failure(error))
                } else {
                    completion(.success(connectionsToReturn))
                }
            }
        } else {
            if let error = errorToReturn {
                completion(.failure(error))
            } else {
                completion(.success(connectionsToReturn))
            }
        }
    }
}
