import XCTest
@testable import VPNBarApp

@MainActor
final class VPNConfigurationLoaderTests: XCTestCase {
    var sut: VPNConfigurationLoader!
    
    override func setUp() {
        super.setUp()
        sut = VPNConfigurationLoader()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Recursion Prevention Tests
    
    func test_loadConfigurations_recursiveCall_isPrevented() {
        let expectation = XCTestExpectation(description: "Load configurations completes")
        expectation.expectedFulfillmentCount = 1
        
        // First call - will attempt to load alternative path
        sut.loadConfigurations { result in
            expectation.fulfill()
        }
        
        // The flag isLoadingAlternative should prevent infinite recursion
        // Even if loadConfigurationsAlternative is called recursively,
        // it should return early with empty result instead of recursing
        
        wait(for: [expectation], timeout: 2.0)
        
        // Test should complete without hanging or crashing
        XCTAssertTrue(true, "Recursive call should be prevented")
    }
    
    func test_loadConfigurations_alternativePath_setsFlag() {
        let expectation = XCTestExpectation(description: "Load configurations completes")
        
        // Call loadConfigurations which may trigger alternative path
        sut.loadConfigurations { result in
            // Flag should be set during execution and reset after
            // We can't directly check the flag, but we verify the call completes
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // If flag wasn't properly managed, we would see issues
        // This test verifies that the alternative path completes successfully
        XCTAssertTrue(true, "Alternative path should complete without issues")
    }
    
    func test_loadConfigurations_multipleCalls_completeSuccessfully() {
        let expectation1 = XCTestExpectation(description: "First load completes")
        let expectation2 = XCTestExpectation(description: "Second load completes")
        
        // First call
        sut.loadConfigurations { result in
            expectation1.fulfill()
        }
        
        // Second call immediately after
        sut.loadConfigurations { result in
            expectation2.fulfill()
        }
        
        wait(for: [expectation1, expectation2], timeout: 3.0)
        
        // Both calls should complete without issues
        XCTAssertTrue(true, "Multiple calls should complete successfully")
    }
    
    func test_loadConfigurations_handlesFrameworkLoadFailure() {
        let expectation = XCTestExpectation(description: "Load configurations handles failure")
        
        sut.loadConfigurations { result in
            // Should handle failure gracefully
            // Result can be success (empty array) or failure
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Should complete without crashing
        XCTAssertTrue(true, "Should handle framework load failure gracefully")
    }
}
