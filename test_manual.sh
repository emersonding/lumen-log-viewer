#!/bin/bash
# Manual E2E Testing Guide for LogViewer
# Run this script to perform manual testing

set -e

echo "════════════════════════════════════════════════════════════"
echo "   LogViewer Manual E2E Test Suite"
echo "════════════════════════════════════════════════════════════"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

APP_PATH="build/LogViewer.app"
TEST_LOG="test_sample.log"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ App not found at $APP_PATH${NC}"
    echo "Run ./build_app.sh first!"
    exit 1
fi

echo -e "${GREEN}✅ App found at $APP_PATH${NC}"
echo ""

# Check if test log exists
if [ ! -f "$TEST_LOG" ]; then
    echo -e "${RED}❌ Test log not found at $TEST_LOG${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Test log found at $TEST_LOG${NC}"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "   Test Instructions"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "The app will now launch. Follow these steps:"
echo ""
echo "1. VERIFY APP LAUNCHES"
echo "   ${YELLOW}→ Check if LogViewer icon appears in Dock${NC}"
echo "   ${YELLOW}→ Check if window opens${NC}"
echo ""
echo "2. OPEN TEST FILE"
echo "   ${YELLOW}→ Click 'Open File' or press Cmd+O${NC}"
echo "   ${YELLOW}→ Select 'test_sample.log' from this directory${NC}"
echo "   ${YELLOW}→ Verify 15 log lines appear${NC}"
echo ""
echo "3. CHECK CONSOLE OUTPUT"
echo "   ${YELLOW}→ Look for debug output in this terminal:${NC}"
echo "      ✅ File opened successfully"
echo "      📊 Total entries parsed: 15"
echo "      🎯 Filters applied"
echo ""
echo "4. TEST FILTERING"
echo "   ${YELLOW}→ Click ERROR filter button to toggle it off${NC}"
echo "   ${YELLOW}→ Verify ERROR lines disappear (should show 11 lines)${NC}"
echo "   ${YELLOW}→ Toggle ERROR back on (should show 15 lines again)${NC}"
echo ""
echo "5. TEST SEARCH"
echo "   ${YELLOW}→ Press Cmd+F to focus search bar${NC}"
echo "   ${YELLOW}→ Type 'database'${NC}"
echo "   ${YELLOW}→ Verify matching lines are highlighted${NC}"
echo "   ${YELLOW}→ Press Cmd+G to jump to next match${NC}"
echo ""
echo "6. TEST REFRESH"
echo "   ${YELLOW}→ Press Cmd+R to refresh${NC}"
echo "   ${YELLOW}→ Verify file reloads successfully${NC}"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

read -p "Press Enter to launch the app with test file..."

echo ""
echo -e "${GREEN}🚀 Launching LogViewer...${NC}"
echo ""

# Launch the app with test log file
# Console output will appear in this terminal
open "$APP_PATH" --args "$(pwd)/$TEST_LOG"

echo ""
echo -e "${YELLOW}👀 Watch for debug output above ☝️${NC}"
echo ""
echo "After testing, press Ctrl+C to exit this script."
echo ""

# Keep script running to show console output
tail -f /dev/null
