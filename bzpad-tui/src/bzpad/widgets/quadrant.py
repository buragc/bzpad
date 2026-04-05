"""Quadrant panel widget for displaying tasks in an Eisenhower quadrant."""

from __future__ import annotations

from textual.containers import Vertical
from textual.reactive import reactive
from textual.widgets import Label, ListItem, ListView, Static

from ..models import Quadrant, Task
from ..urgency import UrgencyCalculator


class TaskListItem(ListItem):
    """A single task item in the quadrant list."""

    def __init__(self, task: Task, index: int) -> None:
        # Build display text
        title = task.display_title()
        labels = task.display_labels()
        due = task.display_due_date()

        display = f"{title}"
        if labels:
            display += f" [dim]{labels}[/dim]"
        if due:
            urgency = UrgencyCalculator.calculate(task.due)
            if urgency.level.value == "overdue":
                display += f" [bold red]{due}[/bold red]"
            elif urgency.level.value in ("critical", "warning"):
                display += f" [yellow]{due}[/yellow]"
            else:
                display += f" [dim]{due}[/dim]"

        super().__init__(Label(display))
        self._task_data = task
        self._index_data = index


class QuadrantPanel(Vertical):
    """A panel displaying tasks for one Eisenhower quadrant."""

    DEFAULT_CSS = """
    QuadrantPanel {
        border: solid $primary;
        padding: 0;
        height: 100%;
    }
    QuadrantPanel.--active {
        border: solid $accent;
    }
    QuadrantPanel > Static.header {
        background: $primary;
        color: $text;
        padding: 0 1;
        height: auto;
        text-align: center;
        text-style: bold;
    }
    QuadrantPanel.--active > Static.header {
        background: $accent;
    }
    QuadrantPanel > ListView {
        border: none;
        padding: 0;
        height: 1fr;
    }
    QuadrantPanel ListItem {
        padding: 0 1;
    }
    QuadrantPanel ListItem:hover {
        background: $surface-lighten-1;
    }
    QuadrantPanel ListItem.--highlight {
        background: $accent-darken-2;
    }
    """

    quadrant: reactive[Quadrant] = reactive(Quadrant.DO_NOW)
    tasks: reactive[list[Task]] = reactive(lambda: [])
    selected_index: reactive[int] = reactive(0)

    def __init__(self, quadrant: Quadrant, tasks: list[Task] | None = None) -> None:
        super().__init__()
        self._task_list: ListView | None = None
        self.quadrant = quadrant
        self.tasks = tasks or []

    def compose(self):
        """Compose the quadrant panel."""
        yield Static(self.quadrant.display_name, classes="header")
        self._task_list = ListView(*self._create_list_items())
        yield self._task_list

    def _create_list_items(self) -> list[TaskListItem]:
        """Create list items from tasks, sorted by urgency."""
        sorted_tasks = sorted(self.tasks, key=lambda t: UrgencyCalculator.sort_key(t.due))
        return [TaskListItem(task, i) for i, task in enumerate(sorted_tasks)]

    def watch_tasks(self, tasks: list[Task]) -> None:
        """Update the list when tasks change."""
        if self._task_list is not None and self.is_mounted:
            self._task_list.clear()
            for item in self._create_list_items():
                self._task_list.append(item)

    def get_selected_task(self) -> Task | None:
        """Get the currently selected task."""
        if self._task_list is None:
            return None
        highlighted = self._task_list.highlighted_child
        if highlighted is None:
            return None
        if isinstance(highlighted, TaskListItem):
            return highlighted._task_data
        return None

    def on_mount(self) -> None:
        """Called when widget is mounted."""
        self._task_list = self.query_one(ListView)

    def focus_list(self) -> None:
        """Focus the task list."""
        if self._task_list:
            self._task_list.focus()

    def select_next(self) -> None:
        """Select the next item."""
        if self._task_list:
            self._task_list.action_cursor_down()

    def select_previous(self) -> None:
        """Select the previous item."""
        if self._task_list:
            self._task_list.action_cursor_up()

    @property
    def task_count(self) -> int:
        """Get the number of tasks in this quadrant."""
        return len(self.tasks)
