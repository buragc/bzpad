"""Tests for urgency module."""

import unittest
from datetime import datetime, timedelta
from unittest.mock import patch

from bzpad.models import TodoistDue
from bzpad.urgency import UrgencyCalculator, UrgencyLevel


class TestUrgencyCalculator(unittest.TestCase):
    """Test UrgencyCalculator."""

    def test_calculate_no_due_date(self) -> None:
        """Test calculation with no due date."""
        result = UrgencyCalculator.calculate(None)
        self.assertEqual(result.level, UrgencyLevel.NORMAL)
        self.assertIsNone(result.days_until)
        self.assertEqual(result.display_prefix, "")
        self.assertEqual(result.display_date, "")

    def test_calculate_overdue(self) -> None:
        """Test overdue task."""
        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        due = TodoistDue(date=yesterday, string="Yesterday")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.OVERDUE)
        self.assertLess(result.days_until, 0)
        self.assertEqual(result.display_prefix, "!")
        self.assertIn("!", result.display_date)

    def test_calculate_due_today(self) -> None:
        """Test task due today."""
        today = datetime.now().strftime("%Y-%m-%d")
        due = TodoistDue(date=today, string="Today")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.CRITICAL)
        self.assertEqual(result.days_until, 0)
        self.assertEqual(result.display_prefix, "~")

    def test_calculate_due_tomorrow(self) -> None:
        """Test task due tomorrow (warning level)."""
        tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        due = TodoistDue(date=tomorrow, string="Tomorrow")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.WARNING)
        self.assertEqual(result.days_until, 1)
        self.assertEqual(result.display_prefix, "~")

    def test_calculate_due_in_2_days(self) -> None:
        """Test task due in 2 days (warning level)."""
        future = (datetime.now() + timedelta(days=2)).strftime("%Y-%m-%d")
        due = TodoistDue(date=future, string="In 2 days")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.WARNING)
        self.assertEqual(result.days_until, 2)

    def test_calculate_due_in_5_days(self) -> None:
        """Test task due in 5 days (soon level)."""
        future = (datetime.now() + timedelta(days=5)).strftime("%Y-%m-%d")
        due = TodoistDue(date=future, string="In 5 days")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.SOON)
        self.assertEqual(result.days_until, 5)
        self.assertEqual(result.display_prefix, "~")

    def test_calculate_due_in_8_days(self) -> None:
        """Test task due in 8 days (normal level)."""
        future = (datetime.now() + timedelta(days=8)).strftime("%Y-%m-%d")
        due = TodoistDue(date=future, string="In 8 days")
        result = UrgencyCalculator.calculate(due)
        self.assertEqual(result.level, UrgencyLevel.NORMAL)
        self.assertEqual(result.days_until, 8)
        self.assertEqual(result.display_prefix, "")

    def test_get_prefix_overdue(self) -> None:
        """Test getting prefix for overdue."""
        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        due = TodoistDue(date=yesterday)
        self.assertEqual(UrgencyCalculator.get_prefix(due), "!")

    def test_get_prefix_normal(self) -> None:
        """Test getting prefix for normal."""
        future = (datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d")
        due = TodoistDue(date=future)
        self.assertEqual(UrgencyCalculator.get_prefix(due), "")

    def test_is_urgent_overdue(self) -> None:
        """Test overdue is urgent."""
        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        due = TodoistDue(date=yesterday)
        self.assertTrue(UrgencyCalculator.is_urgent(due))

    def test_is_urgent_today(self) -> None:
        """Test due today is urgent."""
        today = datetime.now().strftime("%Y-%m-%d")
        due = TodoistDue(date=today)
        self.assertTrue(UrgencyCalculator.is_urgent(due))

    def test_is_urgent_future(self) -> None:
        """Test far future is not urgent."""
        future = (datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d")
        due = TodoistDue(date=future)
        self.assertFalse(UrgencyCalculator.is_urgent(due))

    def test_sort_key_urgent_first(self) -> None:
        """Test sort key puts urgent tasks first."""
        yesterday = TodoistDue(date=(datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d"))
        today = TodoistDue(date=datetime.now().strftime("%Y-%m-%d"))
        future = TodoistDue(date=(datetime.now() + timedelta(days=10)).strftime("%Y-%m-%d"))
        none_due = None

        overdue_key = UrgencyCalculator.sort_key(yesterday)
        today_key = UrgencyCalculator.sort_key(today)
        future_key = UrgencyCalculator.sort_key(future)
        none_key = UrgencyCalculator.sort_key(none_due)

        # Urgent tasks (overdue, today) should come before non-urgent
        self.assertLess(overdue_key, future_key)
        self.assertLess(today_key, future_key)
        # Both overdue and today are urgent, but overdue is more urgent
        self.assertLess(overdue_key, today_key)
        # Tasks with due dates come before those without
        self.assertLess(future_key, none_key)

    def test_format_due_date(self) -> None:
        """Test formatting due date."""
        due = TodoistDue(date="2024-03-15", string="Mar 15")
        result = UrgencyCalculator.format_due_date(due)
        self.assertIn("Mar 15", result)


if __name__ == "__main__":
    unittest.main()
