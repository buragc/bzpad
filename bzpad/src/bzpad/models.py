"""Data models for Todoist API and internal task representation."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any


class Quadrant(Enum):
    """Eisenhower matrix quadrants."""

    DO_NOW = "do_now"  # Urgent & Important
    PLAN = "plan"  # Not Urgent & Important
    HAND_OFF = "hand_off"  # Urgent & Not Important
    DROP = "drop"  # Not Urgent & Not Important

    @property
    def display_name(self) -> str:
        """Human-readable name for display."""
        return {
            Quadrant.DO_NOW: "Do Now",
            Quadrant.PLAN: "Do This Week",
            Quadrant.HAND_OFF: "Do This Month",
            Quadrant.DROP: "Maybe One Day",
        }[self]


@dataclass
class TodoistDue:
    """Todoist due date representation."""

    date: str  # YYYY-MM-DD format
    datetime: str | None = None  # ISO format with timezone
    string: str = ""  # Human-readable due string
    lang: str = "en"
    is_recurring: bool = False

    @classmethod
    def from_api(cls, data: dict[str, Any] | None) -> TodoistDue | None:
        """Create from API response."""
        if not data:
            return None
        return cls(
            date=data.get("date", ""),
            datetime=data.get("datetime"),
            string=data.get("string", ""),
            lang=data.get("lang", "en"),
            is_recurring=data.get("is_recurring", False),
        )

    def to_datetime(self) -> datetime | None:
        """Convert to Python datetime."""
        if self.datetime:
            try:
                # Handle ISO format with timezone
                return datetime.fromisoformat(self.datetime.replace("Z", "+00:00"))
            except ValueError:
                pass
        if self.date:
            try:
                return datetime.strptime(self.date, "%Y-%m-%d")
            except ValueError:
                pass
        return None


@dataclass
class TodoistTask:
    """Todoist task from API."""

    id: str
    content: str
    description: str = ""
    project_id: str = ""
    section_id: str | None = None
    parent_id: str | None = None
    order: int = 0
    priority: int = 1  # 1 (normal) to 4 (urgent)
    due: TodoistDue | None = None
    labels: list[str] = field(default_factory=list)
    created_at: str = ""
    creator_id: str = ""
    assignee_id: str | None = None
    assigner_id: str | None = None
    comment_count: int = 0
    is_collapsed: bool = False
    url: str = ""

    @classmethod
    def from_api(cls, data: dict[str, Any]) -> TodoistTask:
        """Create from API response."""
        return cls(
            id=str(data.get("id", "")),
            content=data.get("content", ""),
            description=data.get("description", ""),
            project_id=str(data.get("project_id", "")),
            section_id=str(data.get("section_id")) if data.get("section_id") else None,
            parent_id=str(data.get("parent_id")) if data.get("parent_id") else None,
            order=data.get("order", 0),
            priority=data.get("priority", 1),
            due=TodoistDue.from_api(data.get("due")),
            labels=data.get("labels", []),
            created_at=data.get("created_at", ""),
            creator_id=str(data.get("creator_id", "")),
            assignee_id=str(data.get("assignee_id")) if data.get("assignee_id") else None,
            assigner_id=str(data.get("assigner_id")) if data.get("assigner_id") else None,
            comment_count=data.get("comment_count", 0),
            is_collapsed=data.get("is_collapsed", False),
            url=data.get("url", ""),
        )


@dataclass
class TodoistProject:
    """Todoist project from API."""

    id: str
    name: str
    color: str = ""
    parent_id: str | None = None
    order: int = 0
    comment_count: int = 0
    is_shared: bool = False
    is_favorite: bool = False
    is_inbox_project: bool = False
    is_team_inbox: bool = False
    view_style: str = "list"
    url: str = ""

    @classmethod
    def from_api(cls, data: dict[str, Any]) -> TodoistProject:
        """Create from API response."""
        return cls(
            id=str(data.get("id", "")),
            name=data.get("name", ""),
            color=data.get("color", ""),
            parent_id=str(data.get("parent_id")) if data.get("parent_id") else None,
            order=data.get("order", 0),
            comment_count=data.get("comment_count", 0),
            is_shared=data.get("is_shared", False),
            is_favorite=data.get("is_favorite", False),
            is_inbox_project=data.get("is_inbox_project", False),
            is_team_inbox=data.get("is_team_inbox", False),
            view_style=data.get("view_style", "list"),
            url=data.get("url", ""),
        )


@dataclass
class TodoistSection:
    """Todoist section from API."""

    id: str
    name: str
    project_id: str = ""
    order: int = 0

    @classmethod
    def from_api(cls, data: dict[str, Any]) -> TodoistSection:
        """Create from API response."""
        return cls(
            id=str(data.get("id", "")),
            name=data.get("name", ""),
            project_id=str(data.get("project_id", "")),
            order=data.get("order", 0),
        )


@dataclass
class Task:
    """Internal task model combining Todoist data with UI state."""

    id: str
    content: str
    description: str
    due: TodoistDue | None
    labels: list[str]
    section_id: str
    quadrant: Quadrant
    priority: int = 1
    created_at: str = ""

    @classmethod
    def from_todoist(cls, todoist_task: TodoistTask, quadrant: Quadrant) -> Task:
        """Create internal Task from TodoistTask."""
        return cls(
            id=todoist_task.id,
            content=todoist_task.content,
            description=todoist_task.description,
            due=todoist_task.due,
            labels=todoist_task.labels,
            section_id=todoist_task.section_id or "",
            quadrant=quadrant,
            priority=todoist_task.priority,
            created_at=todoist_task.created_at,
        )

    def display_title(self) -> str:
        """Get display title with urgency prefix."""
        from .urgency import UrgencyCalculator

        prefix = UrgencyCalculator.get_prefix(self.due)
        return f"{prefix}{self.content}" if prefix else self.content

    def display_labels(self) -> str:
        """Get labels formatted for display."""
        if not self.labels:
            return ""
        return " " + " ".join(f"#{label}" for label in self.labels)

    def display_due_date(self) -> str:
        """Get formatted due date for display."""
        from .urgency import UrgencyCalculator

        return UrgencyCalculator.format_due_date(self.due)
