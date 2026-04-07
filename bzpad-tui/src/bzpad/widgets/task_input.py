"""Task input modals for creating and editing tasks."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import TYPE_CHECKING

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label, Static

if TYPE_CHECKING:
    from ..models import Task


@dataclass
class ParsedTask:
    """Result of parsing task input text."""

    content: str
    due_string: str | None
    labels: list[str]


class TaskInputModal(ModalScreen[ParsedTask | None]):
    """Modal dialog for entering a new task."""

    DEFAULT_CSS = """
    TaskInputModal {
        align: center middle;
    }
    TaskInputModal > Vertical {
        background: $surface;
        border: solid $primary;
        padding: 0 2;
        width: 80;
        height: auto;
        max-height: 10;
    }
    TaskInputModal Static.title {
        text-align: center;
        text-style: bold;
    }
    TaskInputModal Input {
        margin: 0;
    }
    TaskInputModal Horizontal {
        align: right middle;
        margin-top: 1;
    }
    TaskInputModal Button {
        margin-left: 1;
    }
    """

    def __init__(self, quadrant_name: str) -> None:
        super().__init__()
        self.quadrant_name = quadrant_name

    def compose(self) -> ComposeResult:
        """Compose the modal."""
        with Vertical():
            yield Static(f"New Task — {self.quadrant_name}", classes="title")
            yield Input(placeholder="Enter task...", id="task-input")
            with Horizontal():
                yield Button("Cancel", variant="error", id="cancel")
                yield Button("Create", variant="success", id="create")

    def on_mount(self) -> None:
        """Focus the input on mount."""
        self.query_one("#task-input", Input).focus()

    def _parse_input(self, text: str) -> ParsedTask:
        """Parse task input text.

        Extracts hashtags as labels and due: clause as due_string.
        """
        if not text:
            return ParsedTask(content="", due_string=None, labels=[])

        working = text

        # Extract hashtags
        hashtag_pattern = r'#(\w+)'
        labels = re.findall(hashtag_pattern, working)
        working = re.sub(hashtag_pattern, "", working)

        # Extract due: clause (everything from due: to end, after hashtag removal)
        due_string = None
        due_match = re.search(r'due:(.+)$', working, re.IGNORECASE)
        if due_match:
            due_string = due_match.group(1).strip()
            working = working[:due_match.start()]

        # Remainder is content
        content = working.strip()

        return ParsedTask(
            content=content,
            due_string=due_string,
            labels=labels,
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "cancel":
            self.dismiss(None)
        elif event.button.id == "create":
            input_widget = self.query_one("#task-input", Input)
            text = input_widget.value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    self.dismiss(parsed)

    def on_key(self, event) -> None:
        """Handle key presses."""
        if event.key == "escape":
            self.dismiss(None)
        elif event.key == "enter":
            input_widget = self.query_one("#task-input", Input)
            text = input_widget.value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    self.dismiss(parsed)


class TaskEditModal(ModalScreen[ParsedTask | None]):
    """Modal dialog for editing an existing task."""

    DEFAULT_CSS = """
    TaskEditModal {
        align: center middle;
    }
    TaskEditModal > Vertical {
        background: $surface;
        border: solid $primary;
        padding: 0 2;
        width: 80;
        height: auto;
        max-height: 10;
    }
    TaskEditModal Static.title {
        text-align: center;
        text-style: bold;
    }
    TaskEditModal Input {
        margin: 0;
    }
    TaskEditModal Horizontal {
        align: right middle;
        margin-top: 1;
    }
    TaskEditModal Button {
        margin-left: 1;
    }
    """

    def __init__(self, task: Task) -> None:
        super().__init__()
        self.task = task

    def _build_prefill(self) -> str:
        """Build prefilled input string from task data."""
        parts = [self.task.content]
        for label in self.task.labels:
            parts.append(f"#{label}")
        if self.task.due and self.task.due.string:
            parts.append(f"due:{self.task.due.string}")
        elif self.task.due and self.task.due.date:
            parts.append(f"due:{self.task.due.date}")
        return " ".join(parts)

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static("Edit Task", classes="title")
            yield Input(value=self._build_prefill(), id="task-input")
            with Horizontal():
                yield Button("Cancel", variant="error", id="cancel")
                yield Button("Save", variant="success", id="save")

    def on_mount(self) -> None:
        inp = self.query_one("#task-input", Input)
        inp.focus()
        inp.cursor_position = len(inp.value)

    def _parse_input(self, text: str) -> ParsedTask:
        """Parse task input text (same logic as TaskInputModal)."""
        if not text:
            return ParsedTask(content="", due_string=None, labels=[])
        working = text
        hashtag_pattern = r'#(\w+)'
        labels = re.findall(hashtag_pattern, working)
        working = re.sub(hashtag_pattern, "", working)
        due_string = None
        due_match = re.search(r'due:(.+)$', working, re.IGNORECASE)
        if due_match:
            due_string = due_match.group(1).strip()
            working = working[:due_match.start()]
        content = working.strip()
        return ParsedTask(content=content, due_string=due_string, labels=labels)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel":
            self.dismiss(None)
        elif event.button.id == "save":
            text = self.query_one("#task-input", Input).value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    self.dismiss(parsed)

    def on_key(self, event) -> None:
        if event.key == "escape":
            self.dismiss(None)
        elif event.key == "enter":
            text = self.query_one("#task-input", Input).value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    self.dismiss(parsed)
