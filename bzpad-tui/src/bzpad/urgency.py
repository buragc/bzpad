"""Urgency calculator - pure date math, no storage.

Ported from Swift UrgencyCalculator.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .models import TodoistDue


class UrgencyLevel(Enum):
    """Urgency levels based on days until due date."""

    OVERDUE = "overdue"  # days < 0
    CRITICAL = "critical"  # days == 0
    WARNING = "warning"  # days <= 2
    SOON = "soon"  # days <= 7
    NORMAL = "normal"  # days > 7


@dataclass
class UrgencyResult:
    """Result of urgency calculation."""

    level: UrgencyLevel
    days_until: int | None
    display_prefix: str
    display_date: str


class UrgencyCalculator:
    """Calculate urgency based on due date."""

    @staticmethod
    def calculate(due: "TodoistDue | None") -> UrgencyResult:
        """Calculate urgency for a due date.

        Returns UrgencyResult with level and display info.
        """
        if not due:
            return UrgencyResult(
                level=UrgencyLevel.NORMAL,
                days_until=None,
                display_prefix="",
                display_date="",
            )

        due_datetime = due.to_datetime()
        if not due_datetime:
            return UrgencyResult(
                level=UrgencyLevel.NORMAL,
                days_until=None,
                display_prefix="",
                display_date="",
            )

        # Calculate days until due date (midnight-to-midnight comparison)
        now = datetime.now(due_datetime.tzinfo if due_datetime.tzinfo else None)
        today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        due_day = due_datetime.replace(hour=0, minute=0, second=0, microsecond=0)

        delta = due_day - today
        days_until = delta.days

        # Determine urgency level
        if days_until < 0:
            level = UrgencyLevel.OVERDUE
            prefix = "!"
        elif days_until == 0:
            level = UrgencyLevel.CRITICAL
            prefix = "~"
        elif days_until <= 2:
            level = UrgencyLevel.WARNING
            prefix = "~"
        elif days_until <= 7:
            level = UrgencyLevel.SOON
            prefix = "~"
        else:
            level = UrgencyLevel.NORMAL
            prefix = ""

        # Format display date
        date_str = due_datetime.strftime("%b %d")

        return UrgencyResult(
            level=level,
            days_until=days_until,
            display_prefix=prefix,
            display_date=f"[{prefix}{date_str}]" if prefix else "",
        )

    @staticmethod
    def get_prefix(due: "TodoistDue | None") -> str:
        """Get just the prefix character for display."""
        result = UrgencyCalculator.calculate(due)
        return result.display_prefix

    @staticmethod
    def format_due_date(due: "TodoistDue | None") -> str:
        """Format due date for display with urgency prefix."""
        result = UrgencyCalculator.calculate(due)
        return result.display_date

    @staticmethod
    def is_urgent(due: "TodoistDue | None") -> bool:
        """Check if a task is urgent (overdue, critical, or warning)."""
        result = UrgencyCalculator.calculate(due)
        return result.level in (UrgencyLevel.OVERDUE, UrgencyLevel.CRITICAL, UrgencyLevel.WARNING)

    @staticmethod
    def sort_key(due: "TodoistDue | None") -> tuple:
        """Get sort key for ordering tasks by urgency.

        Returns tuple for sorting: (is_urgent_bool, days_until, has_due_date)
        More urgent tasks come first.
        """
        result = UrgencyCalculator.calculate(due)
        # Tuple: (is_urgent as int descending, days_until ascending, has_date as int descending)
        is_urgent = 1 if UrgencyCalculator.is_urgent(due) else 0
        has_date = 1 if due and due.to_datetime() else 0
        days = result.days_until if result.days_until is not None else 9999
        return (-is_urgent, days, -has_date)
