"""Tests for config module."""

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from bzpad.config import (
    Config,
    delete_config,
    ensure_config_dir,
    get_api_token,
    is_first_run,
    load_config,
    save_config,
)
from bzpad.models import Quadrant


class TestConfig(unittest.TestCase):
    """Test Config dataclass."""

    def test_get_section_id(self) -> None:
        """Test getting section ID for quadrant."""
        config = Config(
            api_token="token",
            project_id="proj123",
            sections={
                "do_now": "sec1",
                "plan": "sec2",
                "hand_off": "sec3",
                "drop": "sec4",
            },
        )
        self.assertEqual(config.get_section_id(Quadrant.DO_NOW), "sec1")
        self.assertEqual(config.get_section_id(Quadrant.PLAN), "sec2")
        self.assertEqual(config.get_section_id(Quadrant.HAND_OFF), "sec3")
        self.assertEqual(config.get_section_id(Quadrant.DROP), "sec4")

    def test_get_section_id_missing(self) -> None:
        """Test getting missing section ID returns None."""
        config = Config(api_token="token", project_id="proj123", sections={})
        self.assertIsNone(config.get_section_id(Quadrant.DO_NOW))

    def test_get_quadrant_for_section(self) -> None:
        """Test getting quadrant from section ID."""
        config = Config(
            api_token="token",
            project_id="proj123",
            sections={
                "do_now": "sec1",
                "plan": "sec2",
            },
        )
        self.assertEqual(config.get_quadrant_for_section("sec1"), Quadrant.DO_NOW)
        self.assertEqual(config.get_quadrant_for_section("sec2"), Quadrant.PLAN)
        self.assertIsNone(config.get_quadrant_for_section("unknown"))

    def test_to_dict(self) -> None:
        """Test serialization to dict."""
        config = Config(
            api_token="mytoken",
            project_id="proj123",
            sections={"do_now": "sec1"},
        )
        data = config.to_dict()
        self.assertEqual(data["api_token"], "mytoken")
        self.assertEqual(data["project_id"], "proj123")
        self.assertEqual(data["sections"], {"do_now": "sec1"})

    def test_from_dict(self) -> None:
        """Test deserialization from dict."""
        data = {
            "api_token": "mytoken",
            "project_id": "proj123",
            "sections": {"do_now": "sec1"},
        }
        config = Config.from_dict(data)
        self.assertEqual(config.api_token, "mytoken")
        self.assertEqual(config.project_id, "proj123")
        self.assertEqual(config.sections, {"do_now": "sec1"})


class TestConfigFileOperations(unittest.TestCase):
    """Test config file operations."""

    def setUp(self) -> None:
        """Set up temporary directory for config."""
        self.temp_dir = tempfile.mkdtemp()
        self.config_path = Path(self.temp_dir) / "config.json"
        self.config_dir = Path(self.temp_dir)
        # Store original values
        import bzpad.config as config_module
        self._orig_config_file = config_module.CONFIG_FILE
        self._orig_config_dir = config_module.CONFIG_DIR
        # Set temporary values
        config_module.CONFIG_FILE = self.config_path
        config_module.CONFIG_DIR = self.config_dir

    def tearDown(self) -> None:
        """Clean up temporary directory."""
        import shutil
        import bzpad.config as config_module
        # Restore original values
        config_module.CONFIG_FILE = self._orig_config_file
        config_module.CONFIG_DIR = self._orig_config_dir
        shutil.rmtree(self.temp_dir)

    def test_save_and_load_config(self) -> None:
        """Test saving and loading config."""
        config = Config(
            api_token="test_token",
            project_id="proj123",
            sections={"do_now": "sec1", "plan": "sec2"},
        )
        save_config(config)

        loaded = load_config()
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded.api_token, "test_token")
        self.assertEqual(loaded.project_id, "proj123")
        self.assertEqual(loaded.sections["do_now"], "sec1")

    def test_load_config_missing(self) -> None:
        """Test loading missing config returns None."""
        # Ensure file doesn't exist
        if self.config_path.exists():
            self.config_path.unlink()
        result = load_config()
        self.assertIsNone(result)

    def test_load_config_invalid_json(self) -> None:
        """Test loading invalid JSON returns None."""
        self.config_path.write_text("not json")
        result = load_config()
        self.assertIsNone(result)


class TestGetApiToken(unittest.TestCase):
    """Test API token resolution."""

    def test_env_var_wins(self) -> None:
        """Test environment variable takes precedence."""
        with patch.dict(os.environ, {"TODOIST_API_TOKEN": "env_token"}):
            with patch("bzpad.config.load_config") as mock_load:
                mock_load.return_value = Config(api_token="file_token")
                token = get_api_token()
                self.assertEqual(token, "env_token")

    def test_config_file_fallback(self) -> None:
        """Test config file used when no env var."""
        with patch.dict(os.environ, {}, clear=True):
            with patch("bzpad.config.load_config") as mock_load:
                mock_load.return_value = Config(api_token="file_token")
                token = get_api_token()
                self.assertEqual(token, "file_token")

    def test_no_token_returns_none(self) -> None:
        """Test None returned when no token anywhere."""
        with patch.dict(os.environ, {}, clear=True):
            with patch("bzpad.config.load_config") as mock_load:
                mock_load.return_value = None
                token = get_api_token()
                self.assertIsNone(token)


class TestIsFirstRun(unittest.TestCase):
    """Test first run detection."""

    def test_no_config_is_first_run(self) -> None:
        """Test True when no config exists."""
        with patch("bzpad.config.get_api_token") as mock_token:
            with patch("bzpad.config.load_config") as mock_load:
                mock_token.return_value = None
                mock_load.return_value = None
                self.assertTrue(is_first_run())

    def test_no_project_id_is_first_run(self) -> None:
        """Test True when config exists but no project_id."""
        with patch("bzpad.config.get_api_token") as mock_token:
            with patch("bzpad.config.load_config") as mock_load:
                mock_token.return_value = "token"
                mock_load.return_value = Config(api_token="token", project_id="")
                self.assertTrue(is_first_run())

    def test_valid_config_not_first_run(self) -> None:
        """Test False when valid config exists."""
        with patch("bzpad.config.get_api_token") as mock_token:
            with patch("bzpad.config.load_config") as mock_load:
                mock_token.return_value = "token"
                mock_load.return_value = Config(
                    api_token="token", project_id="proj123"
                )
                self.assertFalse(is_first_run())


if __name__ == "__main__":
    unittest.main()
