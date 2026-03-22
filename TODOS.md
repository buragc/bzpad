# TODOS — Eisenhower Matrix App (iOS + macOS)
Last updated: 2026-03-22 (build session)
Platform: iOS (P0) + macOS (P0) — SwiftUI native. Web: OUT.

## HIGH PRIORITY (before first TestFlight)

### ✅ T1: Scaffold Xcode project with Swift Package structure
- `EisenhowerCore` Swift Package: Sources/ + Tests/ — **DONE**
- XcodeGen project.yml → `native/bzpad.xcodeproj` — **DONE**
- `bzpad-iOS` + `bzpad-macOS` targets with EisenhowerCore dependency — **DONE**
- Shared SwiftUI views (MatrixView, QuadrantView, TaskCardView, QuickAddView, ArchiveView) — **DONE**

### ✅ T2: GRDB.swift schema + migrations
- Task, Cluster, SyncState models with GRDB conformances — **DONE**
- WAL mode via DatabasePool, schema_meta table, migrations — **DONE**
- `updatedAt` field added for CloudKit conflict resolution — **DONE**
- TaskRepository CRUD + ValueObservation — **DONE**

### ✅ T3: Swift test suite (42 tests, all green)
- QuadrantDetectorTests: 10 tests — **PASS**
- DateParserTests: 7 tests (NSDataDetector + relative phrase regex) — **PASS**
- TagExtractorTests: 7 tests — **PASS**
- UrgencyCalculatorTests: 8 tests — **PASS**
- TaskRepositoryTests: 10 tests (isolated temp SQLite per test) — **PASS**
- Also fixed: DateParser now handles "in N weeks/days/months" via NSRegularExpression pre-pass

### ✅ T11: Natural language date parsing (resolved as part of T3)
- Two-pass: regex for "in N days/weeks/months" + NSDataDetector for everything else

### T4: CloudKit setup + conflict resolution
**What:** CKContainer private database, CKRecord types for Task + Cluster.
  Conflict resolution: last-write-wins on `updatedAt` field (add this to schema).
  Offline queue: `CKModifyRecordsOperation` with retry.
**Why:** FR-5.1.x — primary sync mechanism.
**Note:** `updatedAt` is missing from the data model — ADD IT.
**Effort:** human ~3d / CC ~45min

### T5: Sign in with Apple + account deletion
**What:** SIWA integration (ASAuthorizationAppleIDProvider). Store user `sub` in keychain.
  Account deletion flow (GDPR/CCPA + App Store requirement since iOS 15.4).
  Hide My Email relay handling.
**Why:** FR-4.1.x. App Store REJECTS apps without account deletion if they have accounts.
**Effort:** human ~2d / CC ~20min

### T6: Fix XSS vector in link rendering (if porting any web UI)
**What:** Only allow http/https protocols in rendered task links.
**Why:** `javascript:` URLs can execute code. SwiftUI `Link` is safer than HTML, but still validate.
**Effort:** human ~30min / CC ~2min

## MEDIUM PRIORITY (v1.0)

### ✅ T7: macOS-specific layout (MVP done)
- NavigationSplitView with sidebar (Matrix/Archive) + detail — **DONE** in bzpad/Sources/macOS/bzpadApp.swift
- Remaining: resizable quadrant splitters, quick filter bar (v1.0)

### ✅ T9: iOS app shell (MVP done)
- TabView with Matrix + Archive tabs — **DONE** in bzpad/Sources/iOS/bzpadApp.swift
- Remaining: horizontal paging between quadrants, compact card layout (v1.0)

### T8: APNs daily digest + due date alerts
**What:** Background refresh + local notifications for daily digest.
  Ranking: due date proximity > Q1 > creation date.
  Deep link to quadrant.
**Why:** FR-7.x
**Effort:** human ~2d / CC ~20min

### T9: iPhone swipe-between-quadrants layout
**What:** Horizontal paging (TabView with .page style) or custom PageView.
  Bottom tab bar for quadrant switch.
**Why:** NFR-1.2 for iPhone.
**Effort:** human ~2d / CC ~20min

### T10: DnD in SwiftUI
**What:** Drag-drop between quadrants (within-app DnD).
  On iPad: full 2x2 grid with drag handles.
  On iPhone: drag into bottom bar to move quadrant.
**Why:** FR-1.3.1 — core interaction.
**Note:** SwiftUI DnD is via `onDrag`/`onDrop` or the newer transferable API.
**Effort:** human ~3d / CC ~30min

### T11: Natural language date parsing in Swift
**What:** Port chrono-node date parsing to Swift.
  Options: NSDataDetector (built-in, good for natural language),
  or DateParser Swift package.
  Reference: the React prototype uses chrono-node.
**Why:** FR-1.1.2
**Effort:** human ~1d / CC ~15min

### T12: Git sync (optional, v1.0)
**What:** FR-5.2.x — configure private git repo, export JSON/SQLite.
  Use libgit2 via swift-git or shell out to git binary.
  Store credentials in Keychain.
**Why:** Power user feature for non-iCloud-trust users.
**Effort:** human ~3d / CC ~30min

## LOW PRIORITY (v1.5)

### T13: Focus Mode
**What:** Button that filters to Q1 + overdue tasks only. Toggle on/off.
**Why:** Mentioned in requirements doc design section. High signal-to-noise.
**Effort:** human ~2hr / CC ~5min

### T14: Auto-grouping (keyword + date buckets)
**What:** FR-3.1.x — toggle between manual and auto-grouped view.
  Group by: keyword tags, due date buckets (Today/This Week/This Month/Later).

### T15: Manual clustering UI
**What:** FR-3.2.x — drag tasks together to create named clusters.
  Complex interaction on touch vs pointer.

### T16: Analytics dashboard
**What:** FR-9.x — completion rate charts, quadrant distribution, time-to-completion.
  Requires sufficient usage history. Use Swift Charts (built-in since iOS 16).

### T17: Onboarding flow
**What:** 2-3 onboarding screens explaining Eisenhower quadrants on first launch.
  Many users don't know the methodology.

### T18: Keyboard nav (macOS full spec)
**What:** FR-1.4.x — arrow keys, Tab/Shift+Tab across quadrants, focus ring.
  macOS has full keyboard requirement. Partially easier in SwiftUI via focusable().

### T19: Multi-select + bulk operations
**What:** FR-1.3.3-1.3.4 — Cmd+click, Shift+click multi-select. Bulk move/delete/archive.

## REFERENCE
- React prototype: /Users/buragc/dev/bzpad/src/
  - Data model: src/types.ts
  - Business logic: src/lib/taskUtils.ts
  - Quadrant config: QUADRANT_CONFIG in types.ts
  - Store logic: src/store/useTaskStore.ts (undo, CRUD, filtering patterns)
