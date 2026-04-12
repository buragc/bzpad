"""Configuration management for bzpad.

Config file location: ~/.config/bzpad/config.json
Token resolution order:
1. TODOIST_API_TOKEN environment variable
2. config.json api_token field
3. Interactive prompt (first run)
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from .models import Quadrant


CONFIG_DIR = Path.home() / ".config" / "bzpad"
CONFIG_FILE = CONFIG_DIR / "config.json"


@dataclass
class Config:
    """Application configuration."""

    api_token: str = ""
    project_id: str = ""
    sections: dict[str, str] = field(default_factory=dict)

    def get_section_id(self, quadrant: Quadrant) -> str | None:
        """Get section ID for a quadrant."""
        return self.sections.get(quadrant.value)

    def get_quadrant_for_section(self, section_id: str) -> Quadrant | None:
        """Get quadrant enum for a section ID."""
        for q in Quadrant:
            if self.sections.get(q.value) == section_id:
                return q
        return None

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "api_token": self.api_token,
            "project_id": self.project_id,
            "sections": self.sections,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Config:
        """Create from dictionary."""
        return cls(
            api_token=data.get("api_token", ""),
            project_id=data.get("project_id", ""),
            sections=data.get("sections", {}),
        )


def get_config_path() -> Path:
    """Get the config file path."""
    return CONFIG_FILE


def ensure_config_dir() -> None:
    """Ensure the config directory exists."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)


def load_config() -> Config | None:
    """Load configuration from file.

    Returns None if config doesn't exist or is invalid.
    """
    if not CONFIG_FILE.exists():
        return None

    try:
        with open(CONFIG_FILE, "r") as f:
            data = json.load(f)
        return Config.from_dict(data)
    except (json.JSONDecodeError, IOError, KeyError):
        return None


def save_config(config: Config) -> None:
    """Save configuration to file."""
    ensure_config_dir()
    with open(CONFIG_FILE, "w") as f:
        json.dump(config.to_dict(), f, indent=2)


def get_api_token() -> str | None:
    """Get API token with priority: env var > config file > None.

    Returns the token if found, None otherwise.
    """
    # Check environment variable first (always wins)
    env_token = os.environ.get("TODOIST_API_TOKEN")
    if env_token:
        return env_token

    # Check config file
    config = load_config()
    if config and config.api_token:
        return config.api_token

    return None


def delete_config() -> None:
    """Delete the configuration file."""
    if CONFIG_FILE.exists():
        CONFIG_FILE.unlink()


def is_first_run() -> bool:
    """Check if this is the first run (no valid config)."""
    token = get_api_token()
    config = load_config()
    return token is None or config is None or not config.project_id
