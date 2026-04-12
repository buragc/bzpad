# bzpad-tui

A terminal UI for Eisenhower matrix task management, backed by Todoist.

## Installation

```bash
cd bzpad-tui
pip install -e .
```

## Usage

```bash
# Run the app
bzpad

# Or run directly
python -m bzpad.app
```

## First Run

On first run, you'll be prompted to:
1. Enter your Todoist API token (get it from https://todoist.com/app/settings/integrations)
2. Select a project from your Todoist account

The app will automatically create four sections in that project:
- **Do Now** — Urgent & Important
- **Plan** — Not Urgent & Important
- **Hand Off** — Urgent & Not Important
- **Drop** — Not Urgent & Not Important

## Configuration

Config is stored at `~/.config/bzpad/config.json`.

API token resolution order:
1. `TODOIST_API_TOKEN` environment variable (always wins)
2. `~/.config/bzpad/config.json`
3. Interactive prompt

## Keybindings

| Key | Action |
|-----|--------|
| `^N` | New task in focused quadrant |
| `^K` | Complete selected task |
| `^D` | Delete selected task |
| `M` | Move task to another quadrant |
| `/` or `^F` | Filter (placeholder) |
| `Tab` / `Shift+Tab` | Cycle focus between quadrants |
| `Up` / `Down` | Navigate task list |
| `I` | Show task details |
| `^,` | Re-configure (token/project) |
| `^Q` | Quit |

## Task Input

When creating tasks, use inline syntax:

```
Fix the auth bug due:tomorrow #backend
```

- `#tag` — adds Todoist labels
- `due:date` — sets due date (e.g., `due:tomorrow`, `due:next friday`)

## Urgency Display

Tasks show urgency indicators based on due dates:

| Indicator | Meaning |
|-----------|---------|
| `!` | Overdue |
| `~` | Due today or within 7 days |
| (none) | Due > 7 days or no due date |

## Requirements

- Python 3.11+
- textual
- httpx
