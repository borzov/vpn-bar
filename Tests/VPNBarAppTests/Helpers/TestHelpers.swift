import Foundation
import XCTest
@preconcurrency import Combine
@testable import VPNBarApp

enum TestHelpers {
    static func waitForAsync(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
    
    static func waitForPublisher<T>(
        _ publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            let expectation = XCTestExpectation(description: "Wait for publisher value")
            
            cancellable = publisher
                .first()
                .sink { value in
                    continuation.resume(returning: value)
                    expectation.fulfill()
                }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [cancellable] in
                if !expectation.isInverted {
                    cancellable?.cancel()
                    continuation.resume(throwing: TestError.timeout)
                }
            }
        }
    }
    
    static func waitForCondition(
        condition: @escaping () -> Bool,
        timeout: TimeInterval = 1.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let startTime = Date()
        while !condition() && Date().timeIntervalSince(startTime) < timeout {
            await waitForAsync(timeout: 0.1)
        }
        
        if !condition() {
            XCTFail("Condition not met within timeout", file: file, line: line)
        }
    }
}

enum TestError: Error {
    case timeout
    case invalidState
}

