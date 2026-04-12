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
    description: str = ""


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
        max-height: 12;
    }
    TaskInputModal Static.title {
        text-align: center;
        text-style: bold;
    }
    TaskInputModal Static.label {
        color: $text-muted;
        text-style: italic;
        margin-top: 1;
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
            yield Static("desc:<description>  #tag  due:<when>", classes="label")
            yield Input(placeholder="Description (optional)", id="desc-input")
            with Horizontal():
                yield Button("Cancel", variant="error", id="cancel")
                yield Button("Create", variant="success", id="create")

    def on_mount(self) -> None:
        """Focus the input on mount."""
        self.query_one("#task-input", Input).focus()

    def _parse_input(self, text: str) -> ParsedTask:
        """Parse task input text.

        Extracts hashtags as labels, due: clause as due_string,
        and desc: clause as description.
        """
        if not text:
            return ParsedTask(content="", due_string=None, labels=[], description="")

        working = text

        # Extract hashtags
        hashtag_pattern = r'#(\w+)'
        labels = re.findall(hashtag_pattern, working)
        working = re.sub(hashtag_pattern, "", working)

        # Extract desc: clause (use lookahead to stop at next due:)
        description = ""
        desc_match = re.search(r'desc:\s*(.+?)\s*(?=\s+due:|$)', working, re.IGNORECASE | re.DOTALL)
        if desc_match:
            description = desc_match.group(1).strip()
            # Remove the desc clause cleanly
            before = working[:desc_match.start()].rstrip()
            after_start = desc_match.end()
            # Also consume the space before due: if we're stopping at due:
            rest = working[after_start:]
            if rest.startswith('due:'):
                rest = rest[4:].lstrip()  # remove 'due:' and leading space
            working = (before + " " + rest).strip() if (before and rest) else (before + rest)

        # Extract due: clause (everything from due: to end)
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
            description=description,
        )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button presses."""
        if event.button.id == "cancel":
            self.dismiss(None)
        elif event.button.id == "create":
            input_widget = self.query_one("#task-input", Input)
            desc_widget = self.query_one("#desc-input", Input)
            text = input_widget.value.strip()
            desc_value = desc_widget.value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    # Use UI description field if provided, otherwise use parsed desc:
                    final_desc = desc_value if desc_value else parsed.description
                    self.dismiss(ParsedTask(
                        content=parsed.content,
                        due_string=parsed.due_string,
                        labels=parsed.labels,
                        description=final_desc,
                    ))

    def on_key(self, event) -> None:
        """Handle key presses."""
        if event.key == "escape":
            self.dismiss(None)
        elif event.key == "enter":
            input_widget = self.query_one("#task-input", Input)
            desc_widget = self.query_one("#desc-input", Input)
            text = input_widget.value.strip()
            desc_value = desc_widget.value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    final_desc = desc_value if desc_value else parsed.description
                    self.dismiss(ParsedTask(
                        content=parsed.content,
                        due_string=parsed.due_string,
                        labels=parsed.labels,
                        description=final_desc,
                    ))


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
        max-height: 12;
    }
    TaskEditModal Static.title {
        text-align: center;
        text-style: bold;
    }
    TaskEditModal Static.label {
        color: $text-muted;
        text-style: italic;
        margin-top: 1;
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
        self._task = task

    def _build_prefill(self) -> tuple[str, str]:
        """Build prefilled input strings from task data.

        Returns (task_text, description) where task_text is the content
        line and description is pre-filled in the desc field.
        """
        parts = [self._task.content]
        for label in self._task.labels:
            parts.append(f"#{label}")
        if self._task.due and self._task.due.string:
            parts.append(f"due:{self._task.due.string}")
        elif self._task.due and self._task.due.date:
            parts.append(f"due:{self._task.due.date}")
        return (" ".join(parts), self._task.description)

    def compose(self) -> ComposeResult:
        task_text, description = self._build_prefill()
        with Vertical():
            yield Static("Edit Task", classes="title")
            yield Input(value=task_text, id="task-input")
            yield Static("desc:<description>  #tag  due:<when>", classes="label")
            yield Input(value=description, placeholder="Description (optional)", id="desc-input")
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
            return ParsedTask(content="", due_string=None, labels=[], description="")
        working = text
        hashtag_pattern = r'#(\w+)'
        labels = re.findall(hashtag_pattern, working)
        working = re.sub(hashtag_pattern, "", working)
        description = ""
        desc_match = re.search(r'desc:(.+?)(?:due:|$)', working, re.IGNORECASE | re.DOTALL)
        if desc_match:
            description = desc_match.group(1).strip()
            working = working[:desc_match.start()] + working[desc_match.end():]
        due_string = None
        due_match = re.search(r'due:(.+)$', working, re.IGNORECASE)
        if due_match:
            due_string = due_match.group(1).strip()
            working = working[:due_match.start()]
        content = working.strip()
        return ParsedTask(content=content, due_string=due_string, labels=labels, description=description)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "cancel":
            self.dismiss(None)
        elif event.button.id == "save":
            text = self.query_one("#task-input", Input).value.strip()
            desc_value = self.query_one("#desc-input", Input).value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    final_desc = desc_value if desc_value else parsed.description
                    self.dismiss(ParsedTask(
                        content=parsed.content,
                        due_string=parsed.due_string,
                        labels=parsed.labels,
                        description=final_desc,
                    ))

    def on_key(self, event) -> None:
        if event.key == "escape":
            self.dismiss(None)
        elif event.key == "enter":
            text = self.query_one("#task-input", Input).value.strip()
            desc_value = self.query_one("#desc-input", Input).value.strip()
            if text:
                parsed = self._parse_input(text)
                if parsed.content:
                    final_desc = desc_value if desc_value else parsed.description
                    self.dismiss(ParsedTask(
                        content=parsed.content,
                        due_string=parsed.due_string,
                        labels=parsed.labels,
                        description=final_desc,
                    ))
