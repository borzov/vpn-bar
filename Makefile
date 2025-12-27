.PHONY: test test-unit test-integration coverage clean help

SCHEME = VPNBarApp

help:
	@echo "Available targets:"
	@echo "  test              - Run all tests"
	@echo "  test-unit         - Run unit tests only"
	@echo "  test-integration   - Run integration tests only"
	@echo "  coverage          - Generate code coverage report"
	@echo "  clean             - Clean test artifacts"

test:
	@echo "🧪 Running all tests..."
	@swift test

test-unit:
	@echo "🧪 Running unit tests..."
	@swift test --filter VPNBarAppTests

test-integration:
	@echo "🧪 Running integration tests..."
	@swift test --filter VPNBarAppIntegrationTests

coverage:
	@echo "📊 Generating coverage report..."
	@swift test --enable-code-coverage
	@echo "✅ Coverage data generated. Use Xcode to view coverage report."

clean:
	@echo "🧹 Cleaning test artifacts..."
	@swift package clean
	@echo "✅ Clean complete"


