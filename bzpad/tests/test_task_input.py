"""Tests for task_input module."""

import re
import unittest
from dataclasses import dataclass

# Parse function copied from task_input.py to avoid Textual dependency
def _parse_input(text: str):
    """Parse task input text (copy of TaskInputModal logic)."""
    @dataclass
    class ParsedTask:
        content: str
        due_string: str | None
        labels: list[str]

    if not text:
        return ParsedTask(content="", due_string=None, labels=[])

    working = text

    # Extract hashtags
    hashtag_pattern = r'#(\w+)'
    labels = re.findall(hashtag_pattern, working)
    working = re.sub(hashtag_pattern, "", working)

    # Extract due: clause
    due_string = None
    due_match = re.search(r'due:(.+)$', working, re.IGNORECASE)
    if due_match:
        due_string = due_match.group(1).strip()
        working = working[:due_match.start()]

    content = working.strip()
    return ParsedTask(content=content, due_string=due_string, labels=labels)


class TestTaskInputParsing(unittest.TestCase):
    """Test task input parsing logic."""

    def _parse(self, text: str):
        """Helper to parse text."""
        return _parse_input(text)

    def test_simple_content(self) -> None:
        """Test simple content without tags or due date."""
        result = self._parse("Buy groceries")
        self.assertEqual(result.content, "Buy groceries")
        self.assertIsNone(result.due_string)
        self.assertEqual(result.labels, [])

    def test_single_tag(self) -> None:
        """Test single hashtag."""
        result = self._parse("Fix bug #backend")
        self.assertEqual(result.content, "Fix bug")
        self.assertEqual(result.labels, ["backend"])
        self.assertIsNone(result.due_string)

    def test_multiple_tags(self) -> None:
        """Test multiple hashtags."""
        result = self._parse("Write docs #docs #urgent")
        self.assertEqual(result.content, "Write docs")
        self.assertEqual(result.labels, ["docs", "urgent"])

    def test_due_date(self) -> None:
        """Test due date extraction."""
        result = self._parse("Fix bug due:tomorrow")
        self.assertEqual(result.content, "Fix bug")
        self.assertEqual(result.due_string, "tomorrow")
        self.assertEqual(result.labels, [])

    def test_due_date_with_multi_word(self) -> None:
        """Test due date with multi-word phrase."""
        result = self._parse("Fix bug due:next friday")
        self.assertEqual(result.content, "Fix bug")
        self.assertEqual(result.due_string, "next friday")

    def test_due_date_case_insensitive(self) -> None:
        """Test due: is case insensitive."""
        result = self._parse("Fix bug DUE:tomorrow")
        self.assertEqual(result.content, "Fix bug")
        self.assertEqual(result.due_string, "tomorrow")

    def test_tags_and_due_date(self) -> None:
        """Test both tags and due date."""
        result = self._parse("Fix the auth bug due:tomorrow #backend")
        self.assertEqual(result.content, "Fix the auth bug")
        self.assertEqual(result.due_string, "tomorrow")
        self.assertEqual(result.labels, ["backend"])

    def test_tags_before_and_after_due(self) -> None:
        """Test tags both before and after due date."""
        result = self._parse("Write docs #docs #urgent due:next friday")
        self.assertEqual(result.content, "Write docs")
        self.assertEqual(result.due_string, "next friday")
        self.assertEqual(result.labels, ["docs", "urgent"])

    def test_tag_in_middle_of_due(self) -> None:
        """Test that hashtags are removed before extracting due date."""
        result = self._parse("Task #tag1 due:tomorrow #tag2")
        # Both tags should be extracted
        self.assertIn("tag1", result.labels)
        self.assertIn("tag2", result.labels)
        self.assertEqual(result.due_string, "tomorrow")

    def test_empty_input(self) -> None:
        """Test empty input."""
        result = self._parse("")
        self.assertEqual(result.content, "")
        self.assertIsNone(result.due_string)
        self.assertEqual(result.labels, [])

    def test_whitespace_only(self) -> None:
        """Test whitespace-only input."""
        result = self._parse("   ")
        self.assertEqual(result.content, "")
        self.assertIsNone(result.due_string)

    def test_tag_without_hashword(self) -> None:
        """Test hash followed by non-word characters."""
        result = self._parse("Task #123 # #!@")
        # Only #123 should match (word characters after #)
        self.assertEqual(result.labels, ["123"])

    def test_due_without_value(self) -> None:
        """Test due: without a value - stays in content."""
        result = self._parse("Task due:")
        # When there's nothing after due:, the regex doesn't match
        # so "due:" stays in the content
        self.assertEqual(result.content, "Task due:")
        self.assertIsNone(result.due_string)

    def test_complex_real_world(self) -> None:
        """Test complex real-world example."""
        result = self._parse("Review PR #42 and merge to main #work #urgent due:end of week")
        self.assertEqual(result.content, "Review PR  and merge to main")
        self.assertEqual(result.due_string, "end of week")
        # Note: #42 is also parsed as a tag since it matches #\w+ pattern
        self.assertIn("work", result.labels)
        self.assertIn("urgent", result.labels)


class TestParsedTask(unittest.TestCase):
    """Test ParsedTask dataclass."""

    def test_creation(self) -> None:
        """Test creating a ParsedTask."""
        result = _parse_input("Test content due:tomorrow #work #urgent")
        self.assertEqual(result.content, "Test content")
        self.assertEqual(result.due_string, "tomorrow")
        self.assertEqual(result.labels, ["work", "urgent"])


if __name__ == "__main__":
    unittest.main()
