"""Main Textual application for bzpad TUI."""

from __future__ import annotations

import asyncio
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

from textual.app import App, ComposeResult
from textual.containers import Grid, Horizontal, Vertical
from textual.reactive import reactive
from textual.screen import ModalScreen, Screen
from textual import work
from textual.widgets import Button, Footer, Input, Label, ListItem, ListView, Static

from . import config
from .config import Config, get_api_token, load_config, save_config
from .models import Quadrant, Task
from .todoist import (
    TodoistAuthError,
    TodoistClient,
    TodoistError,
    TodoistRateLimitError,
)
from .widgets.quadrant import QuadrantPanel
from .widgets.task_detail import TaskDetailModal
from .widgets.task_input import ParsedTask, TaskEditModal, TaskInputModal

if TYPE_CHECKING:
    pass


# Section names for Todoist
QUADRANT_NAMES = {
    Quadrant.DO_NOW: "Do Now",
    Quadrant.PLAN: "Do This Week",
    Quadrant.HAND_OFF: "Do This Month",
    Quadrant.DROP: "Maybe One Day",
}


class SetupScreen(Screen):
    """First-run setup screen for API token and project selection."""

    DEFAULT_CSS = """
    SetupScreen {
        align: center middle;
    }
    SetupScreen > Vertical {
        background: $surface;
        border: solid $primary;
        padding: 1 2;
        width: 80;
        height: auto;
    }
    SetupScreen Static.title {
        text-align: center;
        text-style: bold;
        padding-bottom: 1;
    }
    SetupScreen Static.error {
        color: $error;
        padding: 1 0;
    }
    SetupScreen Static.success {
        color: $success;
        padding: 1 0;
    }
    SetupScreen Input {
        margin: 1 0;
    }
    SetupScreen ListView {
        height: 15;
        border: solid $primary;
        margin: 1 0;
    }
    SetupScreen Button {
        margin-top: 1;
    }
    """

    def __init__(self) -> None:
        super().__init__()
        self.client: TodoistClient | None = None
        self.projects: list = []
        self.config = Config()
        self.stage: str = "token"  # token, project

    def compose(self) -> ComposeResult:
        """Compose the setup screen."""
        with Vertical():
            yield Static("bzpad Setup", classes="title")
            yield Static("Enter your Todoist API token:", id="prompt")
            yield Input(placeholder="api token...", password=True, id="token-input")
            yield Static("", id="message")
            yield ListView(id="project-list")
            yield Button("Continue", id="continue-btn", disabled=True)

    def on_mount(self) -> None:
        """Focus input on mount."""
        self.query_one("#token-input", Input).focus()
        self.query_one("#project-list", ListView).display = False

    async def on_input_changed(self, event: Input.Changed) -> None:
        """Validate token when input changes."""
        if self.stage == "token" and event.input.id == "token-input":
            token = event.value.strip()
            if len(token) > 20:  # Basic length check
                self.query_one("#continue-btn", Button).disabled = False
            else:
                self.query_one("#continue-btn", Button).disabled = True

    async def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle continue button."""
        if self.stage == "token":
            await self._validate_token()
        elif self.stage == "project":
            await self._select_project()

    async def _validate_token(self) -> None:
        """Validate the API token and load projects."""
        token_input = self.query_one("#token-input", Input)
        token = token_input.value.strip()
        message = self.query_one("#message", Static)

        if not token:
            message.update("Please enter an API token")
            message.add_class("error")
            return

        message.update("Validating token...")
        message.remove_class("error")

        # Close existing client if any
        if self.client:
            await self.client.close()

        self.client = TodoistClient(token)

        try:
            self.projects = await self.client.get_projects()
            if not self.projects:
                message.update("No projects found. Create a project in Todoist first.")
                message.add_class("error")
                return

            # Show project selection
            self.stage = "project"
            self.config.api_token = token

            project_list = self.query_one("#project-list", ListView)
            project_list.clear()
            for project in self.projects:
                project_list.append(ListItem(Label(f"{project.name}")))

            project_list.display = True
            project_list.focus()

            self.query_one("#prompt", Static).update("Select a project:")
            self.query_one("#token-input", Input).display = False
            message.update(f"Found {len(self.projects)} projects")
            message.add_class("success")

        except TodoistAuthError:
            message.update("Invalid API token. Please check and try again.")
            message.add_class("error")
        except TodoistError as e:
            message.update(f"API error: {e.message}")
            message.add_class("error")

    async def _select_project(self) -> None:
        """Handle project selection."""
        project_list = self.query_one("#project-list", ListView)
        selected = project_list.highlighted_child

        if selected is None:
            return

        index = project_list.children.index(selected)
        if index >= len(self.projects):
            return

        project = self.projects[index]
        self.config.project_id = project.id

        message = self.query_one("#message", Static)
        message.update("Setting up quadrant sections...")
        message.remove_class("error")

        try:
            # Ensure all quadrant sections exist
            sections = await self.client.ensure_quadrant_sections(project.id)
            self.config.sections = {q.value: s_id for q, s_id in sections.items()}

            # Save config
            save_config(self.config)

            message.update("Setup complete! Loading bzpad...")
            message.add_class("success")

            # Close client and switch to main screen
            await self.client.close()
            self.client = None

            # Switch to main screen
            await self.app.push_screen("matrix")

        except TodoistError as e:
            message.update(f"Error creating sections: {e.message}")
            message.add_class("error")

    async def on_key(self, event) -> None:
        """Handle key presses."""
        if event.key == "enter" and self.stage == "project":
            await self._select_project()


class SearchModal(ModalScreen[str | None]):
    """Modal dialog for searching/filtering tasks."""

    DEFAULT_CSS = """
    SearchModal {
        align: center middle;
    }
    SearchModal > Vertical {
        background: $surface;
        border: solid $primary;
        padding: 1 2;
        width: 60;
        height: auto;
    }
    SearchModal Static.title {
        text-align: center;
        text-style: bold;
        padding-bottom: 1;
    }
    SearchModal Input {
        margin: 1 0;
    }
    SearchModal Static.help {
        color: $text-muted;
        text-style: italic;
    }
    """

    def __init__(self, current_query: str = "") -> None:
        super().__init__()
        self.current_query = current_query

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static("Search Tasks", classes="title")
            yield Input(
                value=self.current_query,
                placeholder="Type to filter...",
                id="search-input",
            )
            yield Static("Enter to apply, Esc to cancel, empty to clear", classes="help")

    def on_mount(self) -> None:
        self.query_one("#search-input", Input).focus()

    def on_key(self, event) -> None:
        if event.key == "escape":
            self.dismiss(None)
        elif event.key == "enter":
            query = self.query_one("#search-input", Input).value.strip()
            self.dismiss(query)


class MatrixScreen(Screen):
    """Main Eisenhower matrix screen."""

    DEFAULT_CSS = """
    MatrixScreen {
        layout: grid;
        grid-size: 2 2;
        grid-gutter: 1;
        padding: 1;
    }
    MatrixScreen > QuadrantPanel {
        height: 100%;
    }
    """

    BINDINGS = [
        ("ctrl+j", "prev_quadrant", "◀ Quad"),
        ("ctrl+k", "next_quadrant", "Quad ▶"),
        ("n", "new_task", "New"),
        ("e", "edit_task", "Edit"),
        ("enter", "show_detail", "Detail"),
        ("c", "complete_task", "Complete"),
        ("x", "delete_task", "Delete"),
        ("greater_than_sign", "move_task_forward", "Move ▶"),
        ("less_than_sign", "move_task_back", "◀ Move"),
        ("1", "move_to_quadrant_1", "→Q1"),
        ("2", "move_to_quadrant_2", "→Q2"),
        ("3", "move_to_quadrant_3", "→Q3"),
        ("4", "move_to_quadrant_4", "→Q4"),
        ("slash", "filter", "Search"),
        ("ctrl+q", "quit", "Quit"),
        ("up,k", "navigate_up", ""),
        ("down,j", "navigate_down", ""),
    ]

    def __init__(self) -> None:
        super().__init__()
        self.client: TodoistClient | None = None
        self.config: Config | None = None
        self.tasks_by_quadrant: dict[Quadrant, list[Task]] = {
            q: [] for q in Quadrant
        }
        self.focused_quadrant_idx: int = 0
        self.panels: list[QuadrantPanel] = []
        self.last_refresh: datetime | None = None
        self.is_stale: bool = False
        self.filter_query: str = ""

    def compose(self) -> ComposeResult:
        """Compose the matrix screen."""
        for quadrant in [Quadrant.DO_NOW, Quadrant.PLAN, Quadrant.HAND_OFF, Quadrant.DROP]:
            panel = QuadrantPanel(quadrant, [])
            self.panels.append(panel)
            yield panel
        yield Footer()

    async def on_mount(self) -> None:
        """Load configuration and data on mount."""
        await self._load_config()

    async def _load_config(self) -> None:
        """Load configuration and initialize client."""
        token = get_api_token()
        self.config = load_config()

        if not token or not self.config or not self.config.project_id:
            # Need setup
            self.app.switch_screen("setup")
            return

        self.client = TodoistClient(token)
        await self._refresh_data()

        # Highlight first quadrant
        self._activate_quadrant(0)

        # Start periodic refresh
        self.set_interval(60, self._periodic_refresh)

    async def _refresh_data(self) -> None:
        """Fetch all tasks from Todoist."""
        if not self.client or not self.config:
            return

        try:
            todoist_tasks = await self.client.get_tasks(self.config.project_id)

            # Group by quadrant
            self.tasks_by_quadrant = {q: [] for q in Quadrant}

            for tt in todoist_tasks:
                quadrant = self.config.get_quadrant_for_section(tt.section_id)
                if quadrant:
                    task = Task.from_todoist(tt, quadrant)
                    self.tasks_by_quadrant[quadrant].append(task)

            # Update panels (applying any active filter)
            self._apply_filter()

            self.last_refresh = datetime.now()
            self.is_stale = False
            self._update_footer()

        except TodoistAuthError:
            self.notify("Invalid API token. Please reconfigure.", severity="error")
            self.app.switch_screen("setup")
        except TodoistRateLimitError as e:
            self.is_stale = True
            self._update_footer()
            self.notify(f"Rate limited. Retry after {e.retry_after}s", severity="warning")
        except TodoistError as e:
            self.is_stale = True
            self._update_footer()
            self.notify(f"API error: {e.message}", severity="error")

    async def _periodic_refresh(self) -> None:
        """Periodic refresh of data."""
        if self.last_refresh and datetime.now() - self.last_refresh > timedelta(seconds=60):
            await self._refresh_data()

    def _update_footer(self) -> None:
        """Update footer with status."""
        if not self.config:
            return

        panel = self.panels[self.focused_quadrant_idx]
        quadrant = panel.quadrant
        count = len(self.tasks_by_quadrant[quadrant])

        status = f"{quadrant.display_name} — {count} tasks"
        if self.is_stale:
            status += " [stale]"

        self.sub_title = status

    def _get_focused_panel(self) -> QuadrantPanel:
        """Get the currently focused quadrant panel."""
        return self.panels[self.focused_quadrant_idx]

    # Clockwise order through the 2x2 grid: top-left, top-right, bottom-right, bottom-left
    CLOCKWISE_ORDER = [0, 1, 3, 2]

    def _activate_quadrant(self, panel_idx: int) -> None:
        """Set the active quadrant by panel index, updating visuals."""
        old_panel = self.panels[self.focused_quadrant_idx]
        old_panel.remove_class("--active")
        self.focused_quadrant_idx = panel_idx
        new_panel = self.panels[self.focused_quadrant_idx]
        new_panel.add_class("--active")
        new_panel.focus_list()
        self._update_footer()

    def _cycle_quadrant(self, direction: int) -> None:
        """Cycle quadrant in clockwise (+1) or counter-clockwise (-1) order."""
        cw = self.CLOCKWISE_ORDER
        current_pos = cw.index(self.focused_quadrant_idx)
        next_pos = (current_pos + direction) % len(cw)
        self._activate_quadrant(cw[next_pos])

    def action_next_quadrant(self) -> None:
        """Move focus to next quadrant (clockwise)."""
        self._cycle_quadrant(1)

    def action_prev_quadrant(self) -> None:
        """Move focus to previous quadrant (counter-clockwise)."""
        self._cycle_quadrant(-1)

    def action_navigate_up(self) -> None:
        """Navigate up in current quadrant."""
        self._get_focused_panel().select_previous()

    def action_navigate_down(self) -> None:
        """Navigate down in current quadrant."""
        self._get_focused_panel().select_next()

    @work
    async def action_new_task(self) -> None:
        """Create a new task in the focused quadrant."""
        panel = self._get_focused_panel()

        parsed = await self.app.push_screen_wait(
            TaskInputModal(panel.quadrant.display_name),
        )
        if parsed and self.client and self.config:
            await self._create_task(
                parsed.content,
                parsed.due_string,
                parsed.labels,
                panel.quadrant,
            )

    async def _create_task(
        self,
        content: str,
        due_string: str | None,
        labels: list[str],
        quadrant: Quadrant,
    ) -> None:
        """Create a task via API."""
        if not self.client or not self.config:
            return

        section_id = self.config.get_section_id(quadrant)
        if not section_id:
            self.notify("Section not configured", severity="error")
            return

        try:
            await self.client.create_task(
                content=content,
                project_id=self.config.project_id,
                section_id=section_id,
                due_string=due_string,
                labels=labels,
            )
            self.notify("Task created")
            await self._refresh_data()
        except TodoistError as e:
            self.notify(f"Error creating task: {e.message}", severity="error")

    @work
    async def action_edit_task(self) -> None:
        """Edit the selected task."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task or not self.client:
            return

        parsed = await self.app.push_screen_wait(TaskEditModal(task))
        if parsed:
            try:
                await self.client.update_task(
                    task.id,
                    content=parsed.content,
                    due_string=parsed.due_string,
                    labels=parsed.labels,
                )
                self.notify("Task updated")
                await self._refresh_data()
            except TodoistError as e:
                self.notify(f"Error updating task: {e.message}", severity="error")

    @work
    async def action_show_detail(self) -> None:
        """Show task detail modal."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task:
            self.notify("No task selected")
            return

        await self.app.push_screen_wait(TaskDetailModal(task))

    async def action_complete_task(self) -> None:
        """Complete the selected task."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task or not self.client:
            return

        try:
            await self.client.complete_task(task.id)
            self.notify("Task completed")
            await self._refresh_data()
        except TodoistError as e:
            self.notify(f"Error completing task: {e.message}", severity="error")

    async def action_delete_task(self) -> None:
        """Delete the selected task."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task or not self.client:
            return

        try:
            await self.client.delete_task(task.id)
            self.notify("Task deleted")
            await self._refresh_data()
        except TodoistError as e:
            self.notify(f"Error deleting task: {e.message}", severity="error")

    async def _move_task(self, direction: int) -> None:
        """Move task to adjacent quadrant. direction: +1 forward, -1 back."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task or not self.client or not self.config:
            return

        quadrants = list(Quadrant)
        current_idx = quadrants.index(task.quadrant)
        target_idx = (current_idx + direction) % len(quadrants)
        target_quadrant = quadrants[target_idx]

        target_section_id = self.config.get_section_id(target_quadrant)
        if not target_section_id:
            self.notify("Target section not configured", severity="error")
            return

        try:
            await self.client.move_task(task.id, target_section_id)
            self.notify(f"Moved to {target_quadrant.display_name}")
            await self._refresh_data()
        except TodoistError as e:
            self.notify(f"Error moving task: {e.message}", severity="error")

    async def action_move_task_forward(self) -> None:
        """Move task to next quadrant."""
        await self._move_task(1)

    async def action_move_task_back(self) -> None:
        """Move task to previous quadrant."""
        await self._move_task(-1)

    async def _move_task_to_quadrant(self, target: Quadrant) -> None:
        """Move selected task directly to a specific quadrant."""
        panel = self._get_focused_panel()
        task = panel.get_selected_task()

        if not task or not self.client or not self.config:
            return

        if task.quadrant == target:
            self.notify(f"Already in {target.display_name}")
            return

        section_id = self.config.get_section_id(target)
        if not section_id:
            self.notify("Target section not configured", severity="error")
            return

        try:
            await self.client.move_task(task.id, section_id)
            self.notify(f"Moved to {target.display_name}")
            await self._refresh_data()
        except TodoistError as e:
            self.notify(f"Error moving task: {e.message}", severity="error")

    async def action_move_to_quadrant_1(self) -> None:
        await self._move_task_to_quadrant(Quadrant.DO_NOW)

    async def action_move_to_quadrant_2(self) -> None:
        await self._move_task_to_quadrant(Quadrant.PLAN)

    async def action_move_to_quadrant_3(self) -> None:
        await self._move_task_to_quadrant(Quadrant.HAND_OFF)

    async def action_move_to_quadrant_4(self) -> None:
        await self._move_task_to_quadrant(Quadrant.DROP)

    def _apply_filter(self) -> None:
        """Apply current filter query to all panels."""
        query = self.filter_query.lower()
        for panel in self.panels:
            tasks = self.tasks_by_quadrant[panel.quadrant]
            if query:
                tasks = [
                    t for t in tasks
                    if query in t.content.lower()
                    or query in t.description.lower()
                    or any(query in label.lower() for label in t.labels)
                ]
            panel.tasks = tasks

    @work
    async def action_filter(self) -> None:
        """Open search dialog to filter tasks."""
        result = await self.app.push_screen_wait(SearchModal(self.filter_query))
        if result is not None:
            self.filter_query = result
            self._apply_filter()
            if result:
                self.notify(f"Filtering: \"{result}\"")
            else:
                self.notify("Filter cleared")

    def action_reconfigure(self) -> None:
        """Re-enter setup."""
        config.delete_config()
        if self.client:
            asyncio.create_task(self.client.close())
        self.app.switch_screen("setup")

    def action_quit(self) -> None:
        """Quit the app."""
        if self.client:
            asyncio.create_task(self.client.close())
        self.app.exit()


class BzpadApp(App):
    """Main bzpad TUI application."""

    CSS = """
    Screen {
        align: center middle;
    }
    """

    SCREENS = {
        "setup": SetupScreen,
        "matrix": MatrixScreen,
    }

    DARK_THEMES = {
        "textual-dark",
        "textual-ansi",
        "nord",
        "gruvbox",
        "dracula",
        "tokyo-night",
        "monokai",
        "solarized-dark",
        "catppuccin-mocha",
        "catppuccin-frappe",
        "catppuccin-macchiato",
        "rose-pine",
        "rose-pine-moon",
        "atom-one-dark",
    }

    @property
    def available_themes(self) -> dict[str, "Theme"]:
        """Only expose dark/terminal-like themes."""
        all_themes = super().available_themes
        return {k: v for k, v in all_themes.items() if k in self.DARK_THEMES}

    def __init__(self) -> None:
        super().__init__()
        self._setup_completed: bool = False

    async def on_mount(self) -> None:
        """Determine initial screen."""
        if config.is_first_run():
            self.push_screen("setup")
        else:
            self.push_screen("matrix")


def main() -> None:
    """Entry point."""
    app = BzpadApp()
    app.run()


if __name__ == "__main__":
    main()
