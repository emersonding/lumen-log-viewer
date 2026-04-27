# File Tab Design Plan

**Date:** 2026-04-27
**Task:** Add file tab

## Scope

The app currently tracks `openedFiles`, but it is still a single-session viewer:

- Opening a file replaces `allEntries`, `displayedEntries`, `currentFileURL`, offsets, watcher state, and UI state.
- The sidebar's "Opened" section is metadata, not independent live documents.
- Persistence exists for file history and settings, but not for opened tabs or an active workspace.

Required behavior:

- The app should behave as a single-window log viewer.
- Opening a new file adds a tab at the top of the main view.
- Clicking a tab activates that file.
- Closing a tab removes it and activates a neighbor when needed.
- Open tabs persist across app restart.
- Double-clicking a log file in Finder, `open` file events, drag/drop, and `Cmd+O` should add or activate a tab in the existing app window instead of creating a new window.

## Difficulty

- Recommended design: `moderate-high`
- Full live multi-session tabs: `high`

Why this is not a small UI task:

- [Sources/ViewModels/LogViewModel.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/ViewModels/LogViewModel.swift) is `839` lines and mixes app state, active file state, loading, filtering, refresh, history, and watcher control.
- Multiple views and commands read active-file properties directly (`currentFileURL`, `searchState`, `filterState`, `displayedEntries`, `isLoading`).
- Tab persistence is new structured state, not an extension of the existing history array.

## Design Options

### Option A: Full live session per tab

Each tab owns its own parsed entries, displayed entries, filters, search state, offsets, line index, watcher, and refresh timer.

Pros:

- Instant tab switching
- Per-tab state stays live without reload
- Matches the strongest desktop-tab mental model

Cons:

- Memory grows roughly linearly with open tabs because every tab keeps its own parsed arrays and caches
- Multiple watchers/timers may refresh in parallel
- Requires a real split between app-shell state and per-document session state
- Highest regression risk

Performance impact:

- New file open time per file stays about the same as today
- Total memory becomes cumulative across all open files
- Based on current repo docs, even a `10k`-entry loaded session is roughly `~47MB`; multiple medium/large tabs would become expensive quickly

### Option B: One live session, persistent tab metadata and per-tab UI snapshots

Keep only the active tab fully loaded. Inactive tabs persist URL, order, and lightweight UI state. Switching to an inactive tab reuses the existing `openFile` pipeline and restores its saved filter/search state after load.

Pros:

- Memory stays close to today's single-file behavior
- Only one watcher/timer stays active
- Reuses the current parse/filter/render pipeline
- Much smaller refactor than full live sessions

Cons:

- Switching to a previously inactive large tab is not instant; it reloads and reparses

Performance impact:

- Memory: near current single-session baseline plus small tab metadata
- Opening a new file: same as today
- Switching tabs: same cost as opening that file today, which is explicitly acceptable for this task
- App relaunch: persist all tabs, but only eagerly load the active tab on startup

### Option C: Hybrid cache (one active session plus a small warm cache)

Keep one live session and optionally cache one or two recent tab payloads.

Pros:

- Faster switching for a few tabs

Cons:

- Cache invalidation and eviction policy add complexity immediately
- Harder to explain and test
- Not needed for the first version

## Recommendation

Implement **Option B** first.

This satisfies the product requirement while keeping the app's current performance profile stable:

- one parsed dataset in memory
- one active watcher/timer
- one active `NSTableView` datasource
- workspace persistence without committing to multi-document runtime memory costs

This is the best tradeoff unless instant switching across multiple very large logs is a hard requirement.

## Window Behavior

The app should intentionally remain single-window.

Current state:

- The app uses `WindowGroup`, but all windows share one `LogViewModel`, so multiple windows do not provide independent sessions anyway.

Target behavior:

- Keep one primary window for the app.
- File-open requests should route into that existing window and create or activate a tab.
- Disable or avoid user paths that imply separate document windows.

Implementation direction:

- Replace or constrain the current `WindowGroup` setup so the app no longer behaves like a multi-window document app.
- Route Finder/double-click/open-file events through the shared `openOrActivateTab(url:)` path.

## Proposed Runtime Model

Keep the existing active-session properties in `LogViewModel` for now, but add a lightweight workspace layer:

- `openTabs: [FileTab]`
- `activeTabID: UUID?`
- `workspacePersistenceKey`
- `tabSnapshotsByID: [UUID: FileTabSnapshot]`

Suggested models:

- `FileTab`
  - `id`
  - `url`
  - `openedAt`
  - `lastActivatedAt`
- `FileTabSnapshot`
  - `filterState`
  - `searchQuery`
  - `isCaseSensitive`
  - `searchMode`
  - `timestampSortOrder`
  - `extractedFieldNames`

Important detail:

- Only the active tab owns runtime-only state such as `allEntries`, `displayedEntries`, `currentFileOffset`, `lineIndex`, `partialLineBuffer`, loading state, and file watching.
- Before switching tabs, save the current tab snapshot.
- After loading the new tab's file, restore that tab's snapshot and re-apply filters.
- Re-index/reload on tab switch is acceptable and should be treated as intentional behavior, not a temporary limitation.

## Persistence Plan

Persist a workspace blob with:

- tab order
- active tab id
- file paths
- per-tab lightweight UI snapshot

Recommended persistence mechanism:

- JSON-encoded `Codable` workspace in `UserDefaults`

Reasoning:

- Consistent with the app's current use of `UserDefaults` and `@AppStorage`
- Small payload
- No new dependency or file-management surface

Restore behavior:

- On launch, restore the tab list and active tab id
- Eagerly load only the active tab
- If a persisted file no longer exists, remove it from restored tabs and leave it in history only

## UI Plan

Add a tab strip above the existing search bar:

- Horizontal tab row with filename label and close button
- Active tab uses accent/background treatment
- Existing sidebar "Opened" section should mirror the same tab source of truth
- Opening an already-open file should activate its tab instead of duplicating it

Open actions:

- `Cmd+O`: add a new tab in the current window
- Drag and drop: add a new tab in the current window
- Finder/double-click / app `openFile` events: add or activate a tab in the current window

Close behavior:

- Closing inactive tab: remove it only
- Closing active tab: activate the nearest tab, preferring the left neighbor
- Closing the last tab: fall back to the welcome view

## Expected Code Changes

Primary files:

- [Sources/ViewModels/LogViewModel.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/ViewModels/LogViewModel.swift)
  - add tab/workspace state
  - save/restore snapshots
  - add `openOrActivateTab`, `activateTab`, `closeTab`, `persistWorkspace`, `restoreWorkspace`
- [Sources/Models/OpenedFile.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Models/OpenedFile.swift)
  - expand or replace with a codable tab model plus snapshot/workspace models
- [Sources/Views/ContentView.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Views/ContentView.swift)
  - render the top tab strip
  - route open/close actions
- [Sources/Views/SidebarView.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Views/SidebarView.swift)
  - bind to the same tab model as the top strip
- [Sources/LumenApp.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/LumenApp.swift)
  - enforce single-window behavior
  - route file-open events to `openOrActivateTab`
  - optionally add a close-tab command later if desired

Likely touch points:

- [Sources/Views/StatusBarView.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Views/StatusBarView.swift)
- [Sources/Views/FilterBar.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Views/FilterBar.swift)
- [Sources/Views/SearchBar.swift](/Users/emerson/Documents/git/project/log-viewer/Sources/Views/SearchBar.swift)

These should remain mostly unchanged if the active-session API is preserved inside `LogViewModel`.

## Performance and Complexity Cost

### System performance

Recommended design:

- Memory cost: low incremental cost
- New-file load time: unchanged
- Tab-switch load time: equals current file-open path for that file
- Background refresh cost: unchanged because only one file is watched

Rejected full-live-session design:

- Memory cost: high and unbounded relative to tab count and file size
- Background refresh cost: scales with open tabs
- Larger chance of UI churn from multiple sessions changing concurrently

### Codebase complexity

Recommended design:

- Moderate growth in state-management complexity
- UI changes are straightforward
- Main risk is keeping tab snapshot state and active runtime state synchronized

Full-live-session design:

- Requires extracting a per-document view model and re-plumbing most views around an active document reference
- Much bigger testing surface

## Implementation Plan

1. Add codable workspace/tab/snapshot models and persistence helpers.
2. Change app-window behavior to single-window-only and ensure file-open events target the existing window.
3. Convert file-open entry points to `openOrActivateTab(url:)`.
4. Save active-tab snapshot before switching or closing.
5. Restore snapshot after `openFile(url:)` completes for the target tab.
6. Add a top tab strip in `ContentView`.
7. Rebind sidebar opened-files UI to the same tab source.
8. Restore workspace on app launch and auto-open the active tab.
9. Add tests for dedupe, close behavior, snapshot restore, persistence, and single-window open routing.

## Test Plan

Unit tests:

- opening a second file adds a second tab
- opening the same path activates existing tab instead of duplicating
- closing the active tab activates the left neighbor
- switching tabs preserves filter/search/extracted-field state
- workspace persists and restores tab order plus active tab
- missing persisted files are skipped during restore

UI tests:

- two files produce two visible tabs
- clicking a tab changes the active file title/content
- close button removes a tab
- opening a second file targets the same window and adds a tab instead of creating a new window

## Open Questions

- On restore, should missing files stay visible as broken tabs, or should they be dropped and retained only in history?

## Recommended Decision

Proceed with **single-window behavior + persistent tab metadata + one active loaded session** for v1. Reload-on-switch is acceptable by requirement, so the design should optimize for lower memory use and smaller code changes rather than instant tab switching. If later testing shows reload-on-switch is unacceptable, then the next step is a deliberate refactor to extract a per-tab live session model rather than trying to layer it onto the current `LogViewModel`.
