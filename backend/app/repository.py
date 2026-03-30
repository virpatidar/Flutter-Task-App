from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Task, TaskStatus
from .schemas import ApiError, TaskPayload


def list_tasks(db: Session, search: str | None = None, status: str | None = None) -> list[Task]:
    statement = select(Task)

    if search:
        statement = statement.where(Task.title.ilike(f"%{search.strip()}%"))

    if status:
        try:
            parsed_status = TaskStatus(status)
        except ValueError as error:
            allowed = ", ".join(item.value for item in TaskStatus)
            raise ApiError(f"status filter must be one of: {allowed}.", field="status") from error

        statement = statement.where(Task.status == parsed_status)

    statement = statement.order_by(Task.due_date.asc(), Task.id.asc())
    return list(db.scalars(statement).unique().all())


def create_task(db: Session, payload: TaskPayload) -> Task:
    _validate_blocking_rules(db, payload=payload, current_task_id=None)

    task = Task(
        title=payload.title,
        description=payload.description,
        due_date=payload.due_date,
        status=payload.status,
        blocked_by_task_id=payload.blocked_by_task_id,
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def update_task(db: Session, task_id: int, payload: TaskPayload) -> Task:
    task = get_task_or_404(db, task_id)
    _validate_blocking_rules(db, payload=payload, current_task_id=task_id)

    task.title = payload.title
    task.description = payload.description
    task.due_date = payload.due_date
    task.status = payload.status
    task.blocked_by_task_id = payload.blocked_by_task_id

    db.commit()
    db.refresh(task)
    return task


def delete_task(db: Session, task_id: int) -> None:
    task = get_task_or_404(db, task_id)
    db.delete(task)
    db.commit()


def get_task_or_404(db: Session, task_id: int) -> Task:
    task = db.get(Task, task_id)
    if task is None:
        raise ApiError(f"Task {task_id} was not found.", status_code=404)
    return task


def _validate_blocking_rules(
    db: Session,
    payload: TaskPayload,
    current_task_id: int | None,
) -> None:
    blocker_id = payload.blocked_by_task_id
    if blocker_id is None:
        return

    if current_task_id is not None and blocker_id == current_task_id:
        raise ApiError("A task cannot be blocked by itself.", field="blockedByTaskId")

    blocker = db.get(Task, blocker_id)
    if blocker is None:
        raise ApiError("The selected blocker task does not exist.", field="blockedByTaskId")

    if _creates_cycle(db, start_task_id=blocker_id, target_task_id=current_task_id):
        raise ApiError(
            "This dependency would create a circular blocking chain.",
            field="blockedByTaskId",
        )

    if blocker.status != TaskStatus.DONE and payload.status != TaskStatus.TO_DO:
        raise ApiError(
            "Blocked tasks must remain in 'To-Do' until the blocker is marked 'Done'.",
            field="status",
        )


def _creates_cycle(db: Session, start_task_id: int, target_task_id: int | None) -> bool:
    if target_task_id is None:
        return False

    next_task_id = start_task_id

    while next_task_id is not None:
        if next_task_id == target_task_id:
            return True

        current = db.get(Task, next_task_id)
        if current is None:
            return False

        next_task_id = current.blocked_by_task_id

    return False
