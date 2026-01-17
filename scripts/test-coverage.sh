#!/bin/bash
# scripts/test-coverage.sh
# Builds and runs tests with code coverage, generating a coverage report
#
# Usage:
#   ./scripts/test-coverage.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCHEME="Antigravity Stats Menu"
RESULT_BUNDLE="$PWD/.build/TestResults.xcresult"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          Antigravity Stats Menu Test Coverage Runner       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Clean previous results
rm -rf "$RESULT_BUNDLE"
mkdir -p "$PWD/.build"

# Build and run tests
echo -e "${YELLOW}▶ Running tests with code coverage...${NC}"
echo ""

if xcodebuild test \
    -project "Antigravity Stats Menu.xcodeproj" \
    -scheme "$SCHEME" \
    -destination 'platform=macOS' \
    -resultBundlePath "$RESULT_BUNDLE" \
    -enableCodeCoverage YES \
    2>&1 | tee /tmp/xcodebuild.log | grep -E "(Test Case|passed|failed|error:|✓|✗|BUILD|SUCCEEDED|FAILED)"; then
    
    echo ""
    echo -e "${GREEN}✓ All tests passed${NC}"
else
    echo ""
    echo -e "${RED}✗ Some tests failed or could not run${NC}"
fi

echo ""

# Coverage report
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                     CODE COVERAGE REPORT                       ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ -d "$RESULT_BUNDLE" ]; then
    echo -e "${YELLOW}Coverage Summary:${NC}"
    xcrun xccov view --report "$RESULT_BUNDLE" 2>/dev/null | head -30 || \
        echo "No coverage data available"
    
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
    echo -e "Result bundle: $RESULT_BUNDLE"
    echo -e "Open in Xcode: ${GREEN}open \"$RESULT_BUNDLE\"${NC}"
    
    # Export JSON
    xcrun xccov view --report --json "$RESULT_BUNDLE" > "$PWD/.build/coverage.json" 2>/dev/null && \
        echo -e "JSON export:   $PWD/.build/coverage.json"
else
    echo -e "${YELLOW}No test results. Run tests in Xcode for coverage data.${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
