# Architecture Decisions

**Date:** 2026-04-18
**Method:** Claude Code iterative development with manual testing

---

## ADR-1: AppKit NSTableView over SwiftUI LazyVStack

**Status:** Accepted
**Date:** 2026-04-13

### Context

The log viewer needs to display 10k–700k+ log entries with instant filter toggles, smooth scrolling, and syntax-highlighted text. The initial implementation used SwiftUI's `LazyVStack` with manual viewport windowing.

### Problem

Testing with `medium.log` (10,000 rows) revealed three issues with the SwiftUI approach:

1. **Filter unresponsiveness** — Toggling a log level filter caused multi-second freezes. SwiftUI's identity-based diffing algorithm reconciles the entire `displayedEntries` array even though `LazyVStack` only renders visible rows.
2. **Color rendering failures** — Under load, the `SyntaxHighlighter` cache (then 10k entries) was at capacity, causing evictions and race conditions between SwiftUI's render pass and background filtering.
3. **Multiline layout broken** — `LazyVStack` with fixed row heights couldn't accommodate variable-height entries (stack traces).

### Options Evaluated

| Option | Pros | Cons |
|--------|------|------|
| **SwiftUI LazyVStack** | Declarative, simple code | Identity diffing on every filter change; no cell reuse; variable height expensive |
| **SwiftUI LazyVStack + manual windowing** | Reduces rendered views | Still diffs the ForEach range; stale-index crashes when array shrinks; complex scroll math |
| **SwiftUI `List` / `Table`** | Better than LazyVStack | Still SwiftUI diffing; limited customization; no horizontal scroll |
| **AppKit NSTableView** | Native cell reuse; `reloadData()` is O(1); automatic row heights; millions of rows proven | Loses SwiftUI declarativity; NSViewRepresentable boilerplate; manual NSColor instead of SwiftUI Color |

### Decision

**Use AppKit NSTableView via `NSViewRepresentable`.**

The SwiftUI approaches all share a fundamental limitation: replacing `displayedEntries` triggers identity diffing proportional to the array size, regardless of how many views are actually on screen. NSTableView's `reloadData()` simply tells the table "the data changed" — it re-queries only visible rows from the data source.

### Implementation

- `AppKitLogTableView.swift` — `NSViewRepresentable` with `Coordinator` as `NSTableViewDataSource` + `NSTableViewDelegate`
- Two columns: line number gutter (60px, right-aligned) + content (auto-resizing)
- `usesAutomaticRowHeights = true` with `NSTableCellView` + Auto Layout for multiline support
- `filterChangeCounter` in ViewModel signals when to call `reloadData()`
- `SyntaxHighlighter.highlightNS()` builds `NSAttributedString` directly with `NSColor`/`NSFont` (SwiftUI `Color` attributes don't survive the `AttributedString` → `NSAttributedString` conversion)

### Tradeoffs Accepted

- **More imperative code** — The Coordinator pattern is verbose compared to SwiftUI's declarative `ForEach`. ~350 lines vs ~150 for the SwiftUI version.
- **Two highlighting paths** — `highlight()` returns SwiftUI `AttributedString`; `highlightNS()` returns `NSAttributedString`. Separate cache keys (`ns:` prefix) avoid cross-contamination. The SwiftUI path is retained for potential future use (e.g., detail panel).
- **Manual scroll tracking** — `NSView.boundsDidChangeNotification` instead of SwiftUI's `ScrollOffsetPreferenceKey`.
- **Old LogTableView.swift kept** — The SwiftUI windowed version remains in the codebase as reference. It's unused but demonstrates the approach that was tried and abandoned.

### Outcome

Filter toggles on 10k rows: instant. 736k rows: ~12ms. Multiline entries render correctly. Colors work via native `NSColor`. Search match highlighting works via `NSMutableAttributedString`.

---

## ADR-2: Pre-compiled Regex in SyntaxHighlighter

**Status:** Accepted
**Date:** 2026-04-13

### Context

The `SyntaxHighlighter` applies regex-based highlighting for timestamps, log levels, and quoted strings on every cache miss.

### Problem

The original implementation created new `NSRegularExpression` instances on every `highlight()` call — 3 timestamp patterns, 1 level pattern (parameterized per level), and 1 quoted-string pattern. At 5 regex compilations per entry, this added ~1ms per cache miss. For a viewport of 50 rows on first render, that's 50ms of pure regex compilation.

### Decision

Pre-compile all regex patterns at `init()`:

- `timestampRegexes: [NSRegularExpression]` — 3 patterns
- `levelRegexCache: [LogLevel: NSRegularExpression]` — 6 patterns (one per level)
- `quotedStringRegex: NSRegularExpression` — 1 pattern

Total: 10 regex objects compiled once, reused for the lifetime of the highlighter.

### Outcome

Cache-miss highlighting dropped from ~2-5ms to ~0.5-1ms per entry. The init cost is negligible (~1ms total for 10 patterns).

---

## ADR-3: Debounced Single-Pass Filtering

**Status:** Accepted
**Date:** 2026-04-13

### Context

Filter toggles call `applyFilters()` which iterates `allEntries` to produce `displayedEntries`. Users may click multiple filter buttons in quick succession.

### Problem

The original implementation chained multiple `.filter()` calls (level → time range → search), creating intermediate arrays. Each filter toggle triggered a full pass. Rapid toggles caused cascading re-filters.

### Decision

1. **Debounce** — For datasets > 10k entries, `applyFilters()` waits 50ms before executing. Rapid toggles coalesce into one filter pass.
2. **Single-pass filter** — All three filter dimensions (level, time range, search) evaluated per entry in one `.filter()` closure. No intermediate arrays.
3. **Background execution** — Large datasets filter in `Task.detached` to avoid blocking the main thread.

### Outcome

Filtering 736k entries takes ~12ms. Rapid filter toggles don't cascade. UI remains responsive during filtering.

---

## ADR-4: Bracketed Log Level Parsing

**Status:** Accepted
**Date:** 2026-04-13

### Context

The `LogParser` extracts log levels from raw lines. Common log formats use brackets: `[ERROR]`, `[WARNING]`, `[INFO]`.

### Problem

The original `logLevelRegex` pattern `^(FATAL|ERROR|...)\\b` only matched bare keywords at the start of the remaining string after timestamp extraction. After extracting a timestamp like `2026-04-13T10:00:00Z`, the remaining string is ` [ERROR] message`. After trimming whitespace: `[ERROR] message`. The `[` bracket prevented the regex from matching, so **all entries got `level=nil`**.

This caused: no colors on log levels, level filters had no effect, and the app appeared broken on any real-world log file.

### Decision

Update the regex to `^\[?(FATAL|CRITICAL|ERROR|WARN|WARNING|INFO|DEBUG|TRACE)\]?` and use capture group 1 for keyword extraction (without brackets) while consuming the full match (with brackets) from the remaining string.

### Outcome

All standard log formats now parse correctly. Level filters and syntax highlighting colors work as expected.

---

## ADR-5: O(1) Search Match Lookups

**Status:** Accepted
**Date:** 2026-04-13

### Context

In jump-to-match search mode, every visible row checks whether it's a search match to decide on background highlighting.

### Problem

`SearchState.matchingLineIDs` was `[UUID]`. The `isSearchMatch()` function called `.contains(entry.id)` — O(n) per row. For 10k matches and 50 visible rows, that's 500k comparisons per render frame.

### Decision

Add `_matchingLineIDSet: Set<UUID>` kept in sync via `didSet` on `matchingLineIDs`. Add `isMatch(_:)` method that checks the Set. O(1) per lookup.

### Tradeoff

Slight memory overhead (duplicate storage of UUIDs in both array and set). The array is retained for ordered navigation (next/previous match by index).

### Outcome

Search match highlighting is now O(1) per row regardless of match count.

---

## ADR-6: Pre-built Binary Distribution via Homebrew

**Status:** Accepted
**Date:** 2026-04-14

### Context

Lumen is distributed via a personal Homebrew tap (`emersonding/tap`). Users install with `brew install emersonding/tap/lumen`. The fully qualified name is required because an unrelated cask named `lumen` (a screen brightness tool) exists in homebrew-cask.

### Problem

The initial Homebrew formula built from source using `swift build`. This had three issues:

1. **Full Xcode required** — Swift + SwiftUI + AppKit needs the complete macOS SDK, which is only available in Xcode (not Command Line Tools alone). This is a ~7GB install requirement for end users.
2. **Xcode version enforcement** — Homebrew blocks builds when Xcode is more than one minor version behind the latest available. Users with Xcode 26.2 couldn't build when 26.3 was released, even though the code compiles fine on both.
3. **Gatekeeper rejection** — An earlier approach created a `.app` bundle with ad-hoc code signing inside the formula. Homebrew flagged this as "does not pass macOS Gatekeeper check" and marked the formula as deprecated, because ad-hoc signing doesn't satisfy `spctl --assess`. Proper Gatekeeper compliance requires an Apple Developer ID certificate ($99/year) and notarization.

### Options Evaluated

| Option | Pros | Cons |
|--------|------|------|
| **Build from source** | Users can audit code; standard Homebrew approach | Requires full Xcode; blocked by version enforcement; slow build |
| **Homebrew Cask with .app bundle** | Standard for GUI apps; handles quarantine | Name collision with existing `lumen` cask; requires pre-built .app; Gatekeeper issues without Developer ID |
| **Pre-built binary via Formula** | No Xcode needed; fast install; no Gatekeeper on CLI binaries | Users trust the binary; ARM-only unless cross-compiled |
| **Apple Developer ID signing** | Passes Gatekeeper; enables .app distribution | $99/year; notarization workflow complexity |

### Decision

**Distribute a pre-built CLI binary plus an ad-hoc-signed `.app` bundle via Homebrew Formula.** The release script (`scripts/release.sh`) builds locally using the existing `build_app.sh`, packages both the CLI binary (`lumen`) and the `.app` bundle (`Lumen.app`) into a single tarball, uploads it to a GitHub Release, and updates the tap formula to point to the download URL.

Key design choices:
- **Formula ships both `lumen` CLI and `Lumen.app`** — The CLI installs into Homebrew's `bin/` for terminal use; the `.app` bundle is placed under the formula's prefix so users can optionally symlink it into `/Applications` (Launchpad/Dock/Spotlight integration). Caveats in the formula print the symlink command.
- **Ad-hoc signing (`codesign -s -`), no Developer ID** — The `.app` bundle is signed with an ad-hoc identity by `build_app.sh`. Gatekeeper prompts the user to "Open Anyway" on first launch (documented in README and formula caveats). Proper Gatekeeper compliance would require a $99/year Apple Developer ID and notarization, which is out of scope.
- **ARM-only** (`depends_on arch: :arm64`) — Built on Apple Silicon. Cross-compilation for x86_64 is possible but not worth the complexity for the current user base.
- **Formula, not Cask** — Simpler deployment; keeps ownership of both the CLI and the `.app` inside a single formula. Avoids the name collision with the pre-existing `lumen` cask (screen brightness tool) in homebrew-cask.

### Release Flow

```
./scripts/release.sh 2.1.0
  → runs build_app.sh (swift build -c release + ad-hoc sign Lumen.app)
  → packages .build/release/Lumen + build/Lumen.app into lumen-2.1.0-arm64.tar.gz
  → creates GitHub release with the tarball attached
  → copies Formula/lumen.rb to the tap repo, patches url/sha256/version
  → commits and pushes the tap
```

### Tradeoffs Accepted

- **Users trust a pre-built binary** — Source code is available on GitHub for auditing, and the release script is transparent about the build process.
- **ARM-only** — Intel Mac users cannot install. This is acceptable given Apple Silicon adoption since 2020.
- **First-launch Gatekeeper prompt** — Ad-hoc signing means users must approve the app once via System Settings > Privacy & Security. Documented in both the README and formula caveats.

### Outcome

Users install with `brew install emersonding/tap/lumen` — no Xcode, no version constraints. They get both the `lumen` CLI and `Lumen.app` (optionally symlinked into `/Applications`). Install time drops from minutes (source compilation) to seconds (binary download).
