"""Tests for models module."""

import unittest
from datetime import datetime, timezone

from bzpad.models import Quadrant, Task, TodoistDue, TodoistProject, TodoistSection, TodoistTask


class TestQuadrant(unittest.TestCase):
    """Test Quadrant enum."""

    def test_display_names(self) -> None:
        """Test quadrant display names."""
        self.assertEqual(Quadrant.DO_NOW.display_name, "Do Now")
        self.assertEqual(Quadrant.PLAN.display_name, "Do This Week")
        self.assertEqual(Quadrant.HAND_OFF.display_name, "Do This Month")
        self.assertEqual(Quadrant.DROP.display_name, "Maybe One Day")

    def test_quadrant_values(self) -> None:
        """Test quadrant values."""
        self.assertEqual(Quadrant.DO_NOW.value, "do_now")
        self.assertEqual(Quadrant.PLAN.value, "plan")
        self.assertEqual(Quadrant.HAND_OFF.value, "hand_off")
        self.assertEqual(Quadrant.DROP.value, "drop")


class TestTodoistDue(unittest.TestCase):
    """Test TodoistDue dataclass."""

    def test_from_api_with_datetime(self) -> None:
        """Test parsing API response with datetime."""
        data = {
            "date": "2024-03-15",
            "datetime": "2024-03-15T10:00:00Z",
            "string": "Mar 15",
            "lang": "en",
            "is_recurring": False,
        }
        due = TodoistDue.from_api(data)
        self.assertIsNotNone(due)
        self.assertEqual(due.date, "2024-03-15")
        self.assertEqual(due.datetime, "2024-03-15T10:00:00Z")
        self.assertEqual(due.string, "Mar 15")
        self.assertFalse(due.is_recurring)

    def test_from_api_date_only(self) -> None:
        """Test parsing API response with date only."""
        data = {
            "date": "2024-03-15",
            "string": "Mar 15",
        }
        due = TodoistDue.from_api(data)
        self.assertIsNotNone(due)
        self.assertEqual(due.date, "2024-03-15")
        self.assertIsNone(due.datetime)

    def test_from_api_none(self) -> None:
        """Test parsing None returns None."""
        due = TodoistDue.from_api(None)
        self.assertIsNone(due)

    def test_to_datetime_with_datetime(self) -> None:
        """Test converting datetime string to Python datetime."""
        due = TodoistDue(
            date="2024-03-15",
            datetime="2024-03-15T10:00:00+00:00",
            string="Mar 15",
        )
        result = due.to_datetime()
        self.assertIsNotNone(result)
        self.assertEqual(result.year, 2024)
        self.assertEqual(result.month, 3)
        self.assertEqual(result.day, 15)

    def test_to_datetime_with_date_only(self) -> None:
        """Test converting date-only to Python datetime."""
        due = TodoistDue(date="2024-03-15", string="Mar 15")
        result = due.to_datetime()
        self.assertIsNotNone(result)
        self.assertEqual(result.year, 2024)
        self.assertEqual(result.month, 3)
        self.assertEqual(result.day, 15)


class TestTodoistTask(unittest.TestCase):
    """Test TodoistTask dataclass."""

    def test_from_api_basic(self) -> None:
        """Test parsing basic API response."""
        data = {
            "id": "12345",
            "content": "Test task",
            "description": "A description",
            "project_id": "67890",
            "section_id": "sec123",
            "order": 1,
            "priority": 2,
            "labels": ["work", "urgent"],
            "created_at": "2024-01-01T00:00:00Z",
            "creator_id": "user123",
            "comment_count": 0,
            "url": "https://todoist.com/showTask?id=12345",
        }
        task = TodoistTask.from_api(data)
        self.assertEqual(task.id, "12345")
        self.assertEqual(task.content, "Test task")
        self.assertEqual(task.description, "A description")
        self.assertEqual(task.project_id, "67890")
        self.assertEqual(task.section_id, "sec123")
        self.assertEqual(task.order, 1)
        self.assertEqual(task.priority, 2)
        self.assertEqual(task.labels, ["work", "urgent"])
        self.assertEqual(task.url, "https://todoist.com/showTask?id=12345")

    def test_from_api_with_due(self) -> None:
        """Test parsing API response with due date."""
        data = {
            "id": "12345",
            "content": "Due task",
            "due": {
                "date": "2024-03-15",
                "string": "Mar 15",
            },
        }
        task = TodoistTask.from_api(data)
        self.assertIsNotNone(task.due)
        self.assertEqual(task.due.date, "2024-03-15")

    def test_from_api_null_section(self) -> None:
        """Test parsing API response with null section_id."""
        data = {
            "id": "12345",
            "content": "No section",
            "section_id": None,
        }
        task = TodoistTask.from_api(data)
        self.assertIsNone(task.section_id)


class TestTodoistProject(unittest.TestCase):
    """Test TodoistProject dataclass."""

    def test_from_api(self) -> None:
        """Test parsing API response."""
        data = {
            "id": "12345",
            "name": "My Project",
            "color": "red",
            "order": 1,
            "is_shared": False,
            "is_favorite": True,
            "view_style": "list",
            "url": "https://todoist.com/showProject?id=12345",
        }
        project = TodoistProject.from_api(data)
        self.assertEqual(project.id, "12345")
        self.assertEqual(project.name, "My Project")
        self.assertEqual(project.color, "red")
        self.assertTrue(project.is_favorite)
        self.assertFalse(project.is_shared)


class TestTodoistSection(unittest.TestCase):
    """Test TodoistSection dataclass."""

    def test_from_api(self) -> None:
        """Test parsing API response."""
        data = {
            "id": "sec123",
            "name": "Do Now",
            "project_id": "proj456",
            "order": 1,
        }
        section = TodoistSection.from_api(data)
        self.assertEqual(section.id, "sec123")
        self.assertEqual(section.name, "Do Now")
        self.assertEqual(section.project_id, "proj456")
        self.assertEqual(section.order, 1)


class TestTask(unittest.TestCase):
    """Test internal Task model."""

    def test_from_todoist(self) -> None:
        """Test converting TodoistTask to Task."""
        todoist_task = TodoistTask(
            id="12345",
            content="Test content",
            description="A description",
            section_id="sec123",
            labels=["work"],
            priority=2,
            created_at="2024-01-01T00:00:00Z",
        )
        task = Task.from_todoist(todoist_task, Quadrant.DO_NOW)
        self.assertEqual(task.id, "12345")
        self.assertEqual(task.content, "Test content")
        self.assertEqual(task.quadrant, Quadrant.DO_NOW)
        self.assertEqual(task.section_id, "sec123")
        self.assertEqual(task.labels, ["work"])

    def test_display_labels(self) -> None:
        """Test label formatting."""
        task = Task(
            id="1",
            content="Test",
            description="",
            due=None,
            labels=["work", "urgent"],
            section_id="sec",
            quadrant=Quadrant.DO_NOW,
        )
        self.assertEqual(task.display_labels(), " #work #urgent")

    def test_display_labels_empty(self) -> None:
        """Test empty labels return empty string."""
        task = Task(
            id="1",
            content="Test",
            description="",
            due=None,
            labels=[],
            section_id="sec",
            quadrant=Quadrant.DO_NOW,
        )
        self.assertEqual(task.display_labels(), "")


if __name__ == "__main__":
    unittest.main()
