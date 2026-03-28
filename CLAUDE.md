# bzpad — Claude Code Guidelines

## Code Signing — DO NOT TOUCH

**Never modify code signing settings.** Both `bzpad-iOS` and `bzpad-macOS` use `CODE_SIGN_STYLE: Automatic` in `native/project.yml`. Do not change it, do not add `CODE_SIGN_STYLE: Manual`, do not add `DEVELOPMENT_TEAM`, do not touch any signing-related build setting. Xcode manages signing automatically.

## Project layout

```
native/
├── EisenhowerCore/          # Swift Package — business logic, models, storage, tests
│   ├── Sources/EisenhowerCore/
│   │   ├── Logic/           # QuadrantDetector, DateParser, TagExtractor, UrgencyCalculator
│   │   ├── Models/          # Task, Cluster, SyncState
│   │   ├── Storage/         # AppDatabase, Migrations, TaskRepository
│   │   └── Store/           # TaskStore (@Observable)
│   └── Tests/EisenhowerCoreTests/
├── bzpad/
│   └── Sources/
│       ├── Shared/          # SwiftUI views and components used by both platforms
│       ├── iOS/             # iOS-only entry point (bzpadApp.swift)
│       └── macOS/           # macOS-only entry point (bzpadApp.swift)
├── project.yml              # XcodeGen source — edit this, then run `xcodegen generate`
└── bzpad.xcodeproj          # Generated — do NOT edit by hand
src/                         # React/Vite web prototype — REFERENCE ONLY, not the product
TODOS.md                     # Prioritised task backlog
```

## Definition of Done — MUST pass before marking any task complete

### 1. All tests pass

```bash
cd native/EisenhowerCore && swift test
```

All tests must show `Test run with N tests in M suites passed`.

### 2. All Xcode schemes build without errors

Build every scheme. Warnings are acceptable; **errors are not**.

```bash
# iOS
xcodebuild build \
  -project native/bzpad.xcodeproj \
  -scheme bzpad-iOS \
  -destination 'generic/platform=iOS Simulator' \
  2>&1 | grep -E "error:|BUILD FAILED|BUILD SUCCEEDED"

# macOS
xcodebuild build \
  -project native/bzpad.xcodeproj \
  -scheme bzpad-macOS \
  -destination 'generic/platform=macOS' \
  2>&1 | grep -E "error:|BUILD FAILED|BUILD SUCCEEDED"
```

Both must print `BUILD SUCCEEDED` with zero `error:` lines.

> Run these commands yourself — do not assume Xcode builds clean based on SourceKit
> diagnostics alone. SourceKit frequently shows false-positive errors for cross-file
> type references and missing packages that resolve at actual build time.

### 3. No regressions

If you touch EisenhowerCore logic (QuadrantDetector, DateParser, TagExtractor,
UrgencyCalculator, TaskRepository), re-run `swift test` after every change.

## Common pitfalls

- **`Task` name collision**: Our model is `EisenhowerCore.Task`. Use `_Concurrency.Task { }` (not `Task { }`) when launching concurrent work inside EisenhowerCore — otherwise Swift resolves it as our model type and fails to compile.
- **iOS-only UIKit colors**: `Color(.systemGroupedBackground)` etc. are UIKit-backed and unavailable on macOS. Use the adaptors in `Shared/Components/PlatformColors.swift` (`Color.groupedBackground`, `Color.secondaryGroupedBackground`, `Color.tertiaryFill`).
- **`insetGrouped` list style**: macOS-unavailable. Use `.inset` instead, which works on both platforms.
- **SwiftUI `Tab` view**: The iOS 18 `Tab("…", value:)` API conflicts with any local enum named `Tab`. Name local tab enums `AppTab` or similar.
- **XcodeGen**: After changing `project.yml` or adding/removing source files, run `xcodegen generate` from `native/` before building in Xcode.
- **SourceKit false positives**: "No such module 'EisenhowerCore'" and cross-file type-not-found errors in the app target are SourceKit limitations. The actual compiler resolves them. Verify with `xcodebuild`, not by reading SourceKit squiggles.

## Xcode schemes

| Scheme | Platform | Min OS |
|--------|----------|--------|
| `bzpad-iOS` | iPhone + iPad | iOS 17 |
| `bzpad-macOS` | Mac | macOS 14 |
| `EisenhowerCoreTests` | macOS (test host) | macOS 14 |

## Tech stack

- **Swift 6** — strict concurrency enabled (swift-tools-version: 6.0)
- **SwiftUI** — shared views in `Shared/`, platform-specific entry points in `iOS/` and `macOS/`
- **GRDB 7** — SQLite via DatabasePool (WAL mode). No `@vercel/postgres`, no Node.js.
- **Swift Testing** (`@Suite`, `@Test`, `#expect`) — modern test framework, not XCTest
- **XcodeGen** — project file is generated from `native/project.yml`
- **NSDataDetector + NSRegularExpression** — date and hashtag parsing (no third-party NLP)

## React prototype

`src/` contains a Vite/React web MVP. Read it for porting reference (data model,
business logic patterns, Zustand store). **Do not ship or modify it** — it is not the product.
