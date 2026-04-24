# Lumen Testing Guide

## Quick Start

### 1. Rebuild the App
```bash
./build_app.sh
```

### 2. Run Manual Tests
```bash
./test_manual.sh
```

This will:
- Launch the app with a test log file
- Show step-by-step testing instructions
- Display console debug output to help diagnose issues

### 3. Run Automated E2E Tests (Optional)
```bash
chmod +x test_e2e.sh
./test_e2e.sh
```

## Debugging "No Logs Showing" Issue

If the app opens but no logs appear, check the console output:

```bash
./build_app.sh
open build/Lumen.app --args "$(pwd)/test_sample.log" 2>&1 | grep -E "✅|📊|🎯"
```

Look for:
- ✅ File opened successfully
- 📊 Total entries parsed: 15
- 🎯 Filters applied: 15 entries displayed

If you see "0 entries parsed" or "0 entries displayed", the issue is in parsing or filtering.

## Manual Test Checklist

### Basic Functionality
- [ ] App launches and shows Dock icon
- [ ] Window opens with welcome screen
- [ ] Can open file via "Open File" button
- [ ] Can open file via Cmd+O
- [ ] Can drag-and-drop file onto window
- [ ] Log entries display after opening file

### Log Display
- [ ] Line numbers appear in gutter
- [ ] Log levels are color-coded (ERROR=red, WARNING=orange, INFO=default, DEBUG=gray)
- [ ] Timestamps are visible
- [ ] Can scroll through entries
- [ ] Status bar shows correct count (e.g., "15 of 15 lines")

### Filtering
- [ ] Can toggle ERROR filter off/on
- [ ] Can toggle WARNING filter off/on
- [ ] Can toggle INFO filter off/on
- [ ] Can toggle DEBUG filter off/on
- [ ] Can toggle TRACE filter off/on
- [ ] Filter count updates correctly (e.g., hiding ERROR shows "11 of 15 lines")
- [ ] Multiple filters work together (AND logic)

### Search
- [ ] Cmd+F focuses search bar
- [ ] Typing shows match count
- [ ] Matches are highlighted
- [ ] Cmd+G jumps to next match
- [ ] Shift+Cmd+G jumps to previous match

### Refresh
- [ ] Cmd+R refreshes file
- [ ] New content appears after refresh
- [ ] Toolbar refresh button reloads the current file
- [ ] Changing the log font size updates visible rows
- [ ] Adding extracted fields like `request_id`, `user`, or `status` creates columns from `field=value` log messages

### Settings
- [ ] Cmd+L toggles line wrap
- [ ] Cmd+, opens settings

## Test Files

### test_sample.log
Small test file with 15 entries covering all log levels:
- 1 FATAL
- 4 ERROR (including multi-line stack trace)
- 2 WARNING
- 3 INFO
- 2 DEBUG
- 2 TRACE

### Creating Custom Test Files

```bash
# Generate large test file
for i in {1..10000}; do
  echo "2026-04-13 10:00:$((i % 60)) INFO Test entry $i"
done > large_test.log

# Generate file with special characters
echo "2026-04-13 10:00:00 ERROR Failed with: 日本語 émojis 🚀" > special_chars.log
```

## Common Issues

### Issue: No logs showing after opening file

**Symptoms:**
- App opens successfully
- File dialog works
- Window shows but content area is blank or shows "File is empty"

**Debug steps:**
1. Check console output for debug messages
2. Verify file is actually opened: check window title
3. Check if `allEntries` is populated: look for "Total entries parsed: X"
4. Check if `displayedEntries` is populated: look for "Filters applied: X entries displayed"
5. If parsed but not displayed, check filter state

**Possible causes:**
- LogParser failing silently
- applyFilters() not updating displayedEntries
- SwiftUI @Observable not triggering view update
- All filters are disabled

### Issue: App launches but no window appears

**Cause:** App is not properly bundled as .app

**Fix:** Ensure you ran `./build_app.sh`, not just `swift run`

### Issue: App crashes on file open

**Check:** Console for crash logs or error messages

### Issue: Filters don't work

**Check:** Console for "Filters applied" message with correct count

## XCUITest Setup (If Xcode is Available)

If you have Xcode installed, you can run the full UI test suite.
The canonical path uses [xcodegen](https://github.com/yonaskolb/XcodeGen) to
generate the Xcode project from `project.yml`:

```bash
# Generate Xcode project (one-time, or after project.yml changes)
xcodegen generate

# Run UI tests from the command line
xcodebuild test -project Lumen.xcodeproj -scheme Lumen \
  -only-testing LumenUITests -destination 'platform=macOS'

# Or open in Xcode and Cmd+U
open Lumen.xcodeproj
```

> Note: `swift package generate-xcodeproj` has been removed from Swift Package
> Manager. Use `xcodegen generate` (via `project.yml`) for the UI test target.

Then add a UI test target in Xcode with tests like:

```swift
func testOpenFile() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Open File"].tap()
    // ... file picker interaction

    let logTable = app.scrollViews.firstMatch
    XCTAssertTrue(logTable.exists)
}
```

## Performance Testing

```bash
# Generate large file (100MB)
yes "2026-04-13 10:00:00 INFO Test entry" | head -n 1000000 > large.log

# Time the open operation
time open build/Lumen.app --args "$(pwd)/large.log"

# Expected: < 3 seconds for 100MB file
```

## Continuous Testing

Add to your development workflow:

```bash
# After each code change:
./build_app.sh && ./test_manual.sh
```
