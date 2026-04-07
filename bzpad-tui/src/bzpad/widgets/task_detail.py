"""Task detail modal for viewing full task information."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.screen import ModalScreen
from textual.widgets import Static

from ..models import Task


class TaskDetailModal(ModalScreen[None]):
    """Modal showing full details of a task."""

    DEFAULT_CSS = """
    TaskDetailModal {
        align: center middle;
    }
    TaskDetailModal > Vertical {
        background: $surface;
        border: solid $primary;
        padding: 1 2;
        width: 70;
        height: auto;
        max-height: 20;
    }
    TaskDetailModal Static.title {
        text-align: center;
        text-style: bold;
        padding-bottom: 1;
    }
    TaskDetailModal Static.field-label {
        color: $text-muted;
        text-style: italic;
    }
    TaskDetailModal Static.field-value {
        padding-bottom: 1;
    }
    TaskDetailModal Static.hint {
        text-align: center;
        color: $text-muted;
        padding-top: 1;
    }
    """

    def __init__(self, task: Task) -> None:
        super().__init__()
        self.task = task

    def compose(self) -> ComposeResult:
        t = self.task
        with Vertical():
            yield Static(t.content, classes="title")

            if t.description:
                yield Static("Description", classes="field-label")
                yield Static(t.description, classes="field-value")

            if t.due:
                due_text = t.due.string or t.due.date
                yield Static("Due", classes="field-label")
                yield Static(due_text, classes="field-value")

            if t.labels:
                yield Static("Labels", classes="field-label")
                yield Static(" ".join(f"#{l}" for l in t.labels), classes="field-value")

            priority_names = {1: "Normal", 2: "Medium", 3: "High", 4: "Urgent"}
            if t.priority > 1:
                yield Static("Priority", classes="field-label")
                yield Static(priority_names.get(t.priority, str(t.priority)), classes="field-value")

            yield Static("Quadrant", classes="field-label")
            yield Static(t.quadrant.display_name, classes="field-value")

            if t.created_at:
                yield Static("Created", classes="field-label")
                yield Static(t.created_at[:10], classes="field-value")

            yield Static("Esc to close", classes="hint")

    def on_key(self, event) -> None:
        if event.key in ("escape", "enter"):
            self.dismiss(None)
