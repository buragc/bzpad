# bzpad

Eisenhower Matrix task manager — terminal UI edition.

## Architecture

- **`bzpad-tui/`** — Python Textual TUI (active development)
- **`src/`** — React/Vite web prototype (reference only, not the product)

## Quick Start

```bash
cd bzpad-tui
pip install -e .
bzpad
```

## Running Tests

```bash
cd bzpad-tui
pytest
```

## Quadrants

| Quadrant | Urgent | Important | Label |
|----------|--------|-----------|-------|
| Q1 | Yes | Yes | Do First |
| Q2 | No | Yes | Schedule |
| Q3 | Yes | No | Delegate |
| Q4 | No | No | Eliminate |