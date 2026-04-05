# bzpad TUI Rewrite: Todoist Backend + Python/Textual

**Date:** 2026-04-05
**Status:** Approved

## Goal

Rewrite bzpad as a Python/Textual terminal application backed by the Todoist REST API v2. Remove all Swift/SwiftUI/GRDB/EventKit code. The terminal is the only interface.

## Repo Cleanup

Delete entirely:

- `native/` — EisenhowerCore, SwiftUI app (iOS + macOS), TermKit TUI, project.yml, xcodeproj
- `src/` — React/Vite prototype

Keep:

- `CLAUDE.md` (updated to reflect new stack)
- `TODOS.md` (updated)
- Git history

## Project Structure

```
bzpad-tui/
├── pyproject.toml
├── src/
│   └── bzpad/
│       ├── __init__.py
│       ├── app.py              # Textual App, screens, keybindings
│       ├── todoist.py          # httpx async client for Todoist REST API v2
│       ├── models.py           # Dataclasses for API responses + internal task model
│       ├── config.py           # Token + project/section config (~/.config/bzpad/)
│       ├── urgency.py          # UrgencyCalculator (only ported logic module)
│       └── widgets/
│           ├── __init__.py
│           ├── quadrant.py     # Quadrant panel widget
│           └── task_input.py   # Single-field input modal
├── README.md
```

## Dependencies

- `textual` — TUI framework (async-native, built on asyncio)
- `httpx` — async HTTP client

No other runtime dependencies.

## Todoist Data Mapping

### Project + Sections

One user-chosen Todoist project contains four sections representing Eisenhower quadrants:

| Section Name | Quadrant |
|---|---|
| Do Now | Urgent & Important |
| Plan | Not Urgent & Important |
| Hand Off | Urgent & Not Important |
| Drop | Not Urgent & Not Important |

The user picks the project name — we do not assume any default. If any of the four sections are missing, we create them automatically.

### Task Field Mapping

| Eisenhower Concept | Todoist Field | Notes |
|---|---|---|
| Title | `content` | Direct map |
| Quadrant | `section_id` | Which section the task lives in |
| Due date | `due.date` / `due.datetime` | Set via `due_string` on create |
| Tags | `labels` | Todoist labels |
| Notes | `description` | Direct map |
| Completed | Completion API | `POST /tasks/{id}/close` |
| Created at | `created_at` | Read-only from API |

### Dropped Fields

These EisenhowerCore fields have no Todoist equivalent and are not stored:

- `parsedUrgency`, `parsedImportance` — computed on-the-fly from `due.date`
- `clusterName` — unused in TUI
- `source` — no longer meaningful
- `isArchived` — replaced by Todoist's completion model

### Moving a Task

Updating `section_id` via `POST /tasks/{id}` with `{ "section_id": "<target>" }`.

## Todoist API Client

Base URL: `https://api.todoist.com/rest/v2`

Auth: `Authorization: Bearer <token>` header on every request.

### Endpoints

| Operation | Method | Endpoint |
|---|---|---|
| List projects | GET | `/projects` |
| Get sections | GET | `/sections?project_id=X` |
| Create section | POST | `/sections` |
| List active tasks | GET | `/tasks?project_id=X` |
| Create task | POST | `/tasks` |
| Update task | POST | `/tasks/{id}` |
| Complete task | POST | `/tasks/{id}/close` |
| Delete task | DELETE | `/tasks/{id}` |

### Error Handling

- Network failure / non-2xx: show error in status bar, no crash
- 401/403: "Invalid API token" message, prompt to re-enter
- 429: respect `Retry-After` header, show "Rate limited..." in status bar

## Configuration

### File Location

`~/.config/bzpad/config.json`

### Schema

```json
{
  "api_token": "abc123...",
  "project_id": "12345678",
  "sections": {
    "do_now": "90001",
    "plan": "90002",
    "hand_off": "90003",
    "drop": "90004"
  }
}
```

### Token Resolution Order

1. `TODOIST_API_TOKEN` environment variable (always wins)
2. `config.json` `api_token` field
3. Interactive prompt (first run)

## First-Run Flow

1. No token found → SetupScreen prompts "Enter your Todoist API token:"
2. Token validated with `GET /projects`
3. Projects listed in a selection widget → user picks one
4. Sections fetched for that project → missing quadrant sections created
5. Config written to `~/.config/bzpad/config.json`
6. Main MatrixScreen loads

On subsequent runs: load config, validate project/sections still exist (re-enter setup if not), go straight to MatrixScreen.

`Ctrl+,` keybinding to re-enter setup from the main screen.

## Network Strategy

**Read cache + online writes:**

- On launch, fetch all tasks for the project and cache in memory (dict keyed by section ID)
- All reads come from cache — instant rendering
- Mutations (create, complete, move, delete) hit the API first, update cache on success
- Periodic refresh every 60 seconds to pick up changes from other clients
- If last successful fetch is >60s old or a fetch failed, show `[stale]` in the footer

## TUI Layout

```
┌─ bzpad ─────────────────────────────────────────┐
│ ┌─ Do Now ──────────┐ ┌─ Plan ─────────────────┐│
│ │ ! Fix prod bug     │ │   Write Q3 roadmap     ││
│ │ ~ Review PR #42    │ │   Read DDD book        ││
│ │                    │ │                         ││
│ ├─ Hand Off ────────┤ ├─ Drop ─────────────────┤│
│ │   Order supplies   │ │   Reorganize bookmarks ││
│ │                    │ │                         ││
│ └────────────────────┘ └─────────────────────────┘│
│ DO NOW — 2 tasks, 5 done │ ^N New ^K Done ^D Del │
└─────────────────────────────────────────────────┘
```

### Widget Hierarchy

- `BzpadApp(App)` — top-level
  - `SetupScreen(Screen)` — first-run token + project picker
  - `MatrixScreen(Screen)` — main view
    - `QuadrantPanel(Widget)` x 4 — styled task list with header
    - `Footer` — status bar: mode, task count, stale indicator, keybindings

### Keybindings

| Key | Action |
|---|---|
| `^N` | New task in focused quadrant |
| `^K` | Complete selected task |
| `^D` | Delete selected task |
| `M` | Move task to another quadrant |
| `/` or `^F` | Filter by title or label |
| `Tab` / `Shift+Tab` | Cycle focus between quadrants |
| `Up` / `Down` | Navigate task list |
| `I` | Show task detail in footer |
| `^,` | Re-configure (token/project) |
| `^Q` | Quit |

## Task Input

Single input field. User types raw text like:

```
Fix the auth bug due:tomorrow #backend
```

Parsing rules (applied in order):

1. Extract `#hashtag` tokens anywhere in the string — send as Todoist `labels`. Remove from string.
2. Extract `due:` clause — everything from `due:` to the end of the string (after hashtag removal). This allows multi-word dates like `due:next friday`. Send as Todoist `due_string`. Remove from string.
3. Remainder (trimmed) is `content` (the task title).

If no `due:` is present, no due date is set. If no `#tags`, no labels.

Examples:
- `Fix the auth bug due:tomorrow #backend` → content: `Fix the auth bug`, due_string: `tomorrow`, labels: `[backend]`
- `Write docs #docs #urgent due:next friday` → content: `Write docs`, due_string: `next friday`, labels: `[docs, urgent]`
- `Buy groceries` → content: `Buy groceries`, no due date, no labels

## Urgency Display

Ported from Swift `UrgencyCalculator`. Pure date math, no storage:

| Condition | Level | Display |
|---|---|---|
| `days < 0` | overdue | `!` prefix, `[!Mar 15]` |
| `days == 0` | critical | `~` prefix, `[~Mar 15]` |
| `days <= 2` | warning | `~` prefix, `[~Mar 15]` |
| `days <= 7` | soon | `~` prefix, `[~Mar 15]` |
| `days > 7` | normal | no prefix, no date shown |
| no due date | — | no prefix |

Labels displayed as `#tag` suffix after the title.

## Out of Scope

- Offline write queue (mutations require connectivity)
- Todoist comments, attachments, or sub-tasks
- Multiple project support
- Todoist OAuth flow (API token only)
- Syncing completed task history (we only show active tasks)
