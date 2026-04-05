"""Async Todoist API v1 client using httpx."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

from .models import Quadrant, TodoistProject, TodoistSection, TodoistTask

BASE_URL = "https://api.todoist.com/api/v1"

# Section names mapped to quadrants
QUADRANT_SECTION_NAMES = {
    Quadrant.DO_NOW: "Do Now",
    Quadrant.PLAN: "Do This Week",
    Quadrant.HAND_OFF: "Do This Month",
    Quadrant.DROP: "Maybe One Day",
}


class TodoistError(Exception):
    """Base exception for Todoist API errors."""

    def __init__(self, message: str, status_code: int | None = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


class TodoistAuthError(TodoistError):
    """Authentication error (401/403)."""

    pass


class TodoistRateLimitError(TodoistError):
    """Rate limit error (429)."""

    def __init__(self, message: str, retry_after: int = 60):
        super().__init__(message, 429)
        self.retry_after = retry_after


class TodoistClient:
    """Async client for Todoist API v1."""

    def __init__(self, api_token: str):
        self.api_token = api_token
        self.client = httpx.AsyncClient(
            base_url=BASE_URL,
            headers={"Authorization": f"Bearer {api_token}"},
            timeout=30.0,
        )

    async def close(self) -> None:
        """Close the HTTP client."""
        await self.client.aclose()

    async def _request(
        self,
        method: str,
        path: str,
        **kwargs: Any,
    ) -> Any:
        """Make an authenticated request to the API.

        Raises:
            TodoistAuthError: If 401/403 response
            TodoistRateLimitError: If 429 response
            TodoistError: For other non-2xx responses
        """
        response = await self.client.request(method, path, **kwargs)

        if response.status_code == 401 or response.status_code == 403:
            raise TodoistAuthError("Invalid API token", response.status_code)

        if response.status_code == 429:
            retry_after = int(response.headers.get("Retry-After", 60))
            raise TodoistRateLimitError("Rate limited", retry_after)

        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise TodoistError(f"API error: {e}", e.response.status_code)

        if response.status_code == 204:
            return None

        return response.json()

    # Projects

    async def get_projects(self) -> list[TodoistProject]:
        """List all projects."""
        data = await self._request("GET", "/projects")
        items = data.get("results", data) if isinstance(data, dict) else data
        return [TodoistProject.from_api(p) for p in items]

    async def get_project(self, project_id: str) -> TodoistProject:
        """Get a single project by ID."""
        data = await self._request("GET", f"/projects/{project_id}")
        return TodoistProject.from_api(data)

    # Sections

    async def get_sections(self, project_id: str) -> list[TodoistSection]:
        """Get all sections for a project."""
        data = await self._request("GET", "/sections", params={"project_id": project_id})
        items = data.get("results", data) if isinstance(data, dict) else data
        return [TodoistSection.from_api(s) for s in items]

    async def create_section(self, name: str, project_id: str) -> TodoistSection:
        """Create a new section."""
        data = await self._request(
            "POST",
            "/sections",
            json={"name": name, "project_id": project_id},
        )
        return TodoistSection.from_api(data)

    async def ensure_quadrant_sections(
        self, project_id: str
    ) -> dict[Quadrant, str]:
        """Ensure all four quadrant sections exist for a project.

        Returns a mapping of quadrant to section ID.
        """
        existing = await self.get_sections(project_id)
        existing_by_name = {s.name: s for s in existing}

        result: dict[Quadrant, str] = {}

        for quadrant, name in QUADRANT_SECTION_NAMES.items():
            if name in existing_by_name:
                result[quadrant] = existing_by_name[name].id
            else:
                # Create the section
                section = await self.create_section(name, project_id)
                result[quadrant] = section.id

        return result

    # Tasks

    async def get_tasks(self, project_id: str) -> list[TodoistTask]:
        """Get all active tasks for a project."""
        data = await self._request("GET", "/tasks", params={"project_id": project_id})
        items = data.get("results", data) if isinstance(data, dict) else data
        return [TodoistTask.from_api(t) for t in items]

    async def create_task(
        self,
        content: str,
        project_id: str,
        section_id: str | None = None,
        due_string: str | None = None,
        labels: list[str] | None = None,
        description: str = "",
    ) -> TodoistTask:
        """Create a new task."""
        payload: dict[str, Any] = {
            "content": content,
            "project_id": project_id,
        }
        if section_id:
            payload["section_id"] = section_id
        if due_string:
            payload["due_string"] = due_string
        if labels:
            payload["labels"] = labels
        if description:
            payload["description"] = description

        data = await self._request("POST", "/tasks", json=payload)
        return TodoistTask.from_api(data)

    async def update_task(
        self,
        task_id: str,
        content: str | None = None,
        due_string: str | None = None,
        labels: list[str] | None = None,
        description: str | None = None,
    ) -> TodoistTask:
        """Update a task."""
        payload: dict[str, Any] = {}
        if content is not None:
            payload["content"] = content
        if due_string is not None:
            payload["due_string"] = due_string
        if labels is not None:
            payload["labels"] = labels
        if description is not None:
            payload["description"] = description

        data = await self._request("POST", f"/tasks/{task_id}", json=payload)
        return TodoistTask.from_api(data)

    async def move_task(self, task_id: str, section_id: str) -> None:
        """Move a task to a different section."""
        await self._request(
            "POST",
            f"/tasks/{task_id}/move",
            json={"section_id": section_id},
        )

    async def complete_task(self, task_id: str) -> None:
        """Mark a task as complete."""
        await self._request("POST", f"/tasks/{task_id}/close")

    async def delete_task(self, task_id: str) -> None:
        """Delete a task."""
        await self._request("DELETE", f"/tasks/{task_id}")

    # Validation

    async def validate_token(self) -> bool:
        """Validate the API token by fetching projects.

        Returns True if valid, False otherwise.
        """
        try:
            await self.get_projects()
            return True
        except TodoistAuthError:
            return False
