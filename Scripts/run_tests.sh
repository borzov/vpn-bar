#!/bin/bash

set -e

echo "🧪 Running VPNBarApp tests..."

SCHEME="VPNBarApp"
DESTINATION="platform=macOS"

echo "📦 Building tests..."
swift test --enable-code-coverage

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Tests failed!"
    exit 1
fi

