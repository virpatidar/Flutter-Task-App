from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from typing import Any

from .models import Task, TaskStatus


class ApiError(Exception):
    def __init__(self, message: str, status_code: int = 400, field: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.field = field


@dataclass(slots=True)
class TaskPayload:
    title: str
    description: str
    due_date: date
    status: TaskStatus
    blocked_by_task_id: int | None


def parse_task_payload(payload: Any) -> TaskPayload:
    if not isinstance(payload, dict):
        raise ApiError("Request body must be a JSON object.")

    title = _parse_required_text(payload, "title")
    description = _parse_required_text(payload, "description")
    due_date = _parse_due_date(payload.get("dueDate"))
    status = _parse_status(payload.get("status"))
    blocked_by_task_id = _parse_optional_task_id(payload.get("blockedByTaskId"))

    return TaskPayload(
        title=title,
        description=description,
        due_date=due_date,
        status=status,
        blocked_by_task_id=blocked_by_task_id,
    )


def serialize_task(task: Task) -> dict[str, Any]:
    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "dueDate": task.due_date.isoformat(),
        "status": task.status.value,
        "blockedByTaskId": task.blocked_by_task_id,
    }


def _parse_required_text(payload: dict[str, Any], field: str) -> str:
    raw_value = payload.get(field)

    if not isinstance(raw_value, str):
        raise ApiError(f"{field} must be a string.", field=field)

    value = raw_value.strip()
    if not value:
        raise ApiError(f"{field} cannot be empty.", field=field)

    return value


def _parse_due_date(raw_value: Any) -> date:
    if not isinstance(raw_value, str):
        raise ApiError("dueDate must be an ISO date string.", field="dueDate")

    try:
        return date.fromisoformat(raw_value)
    except ValueError as error:
        raise ApiError("dueDate must use YYYY-MM-DD format.", field="dueDate") from error


def _parse_status(raw_value: Any) -> TaskStatus:
    if not isinstance(raw_value, str):
        raise ApiError("status must be a string.", field="status")

    try:
        return TaskStatus(raw_value)
    except ValueError as error:
        allowed = ", ".join(status.value for status in TaskStatus)
        raise ApiError(f"status must be one of: {allowed}.", field="status") from error


def _parse_optional_task_id(raw_value: Any) -> int | None:
    if raw_value is None:
        return None

    if isinstance(raw_value, bool) or not isinstance(raw_value, int) or raw_value <= 0:
        raise ApiError("blockedByTaskId must be a positive integer or null.", field="blockedByTaskId")

    return raw_value
