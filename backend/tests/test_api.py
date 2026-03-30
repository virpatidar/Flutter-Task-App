from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

from app.main import create_app


def _task_payload(title: str, status: str = "To-Do", blocked_by_task_id: int | None = None) -> dict:
    return {
        "title": title,
        "description": f"Description for {title}",
        "dueDate": "2026-04-15",
        "status": status,
        "blockedByTaskId": blocked_by_task_id,
    }


class TaskApiTests(unittest.TestCase):
    def setUp(self) -> None:
        app = create_app("sqlite:///:memory:")
        self.client = app.test_client()

    def test_crud_and_filters(self) -> None:
        response = self.client.post("/api/tasks", json=_task_payload("Plan roadmap"))
        self.assertEqual(response.status_code, 201)
        created_task = response.get_json()
        self.assertEqual(created_task["title"], "Plan roadmap")

        response = self.client.put(
            f"/api/tasks/{created_task['id']}",
            json=_task_payload("Plan roadmap", status="Done"),
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["status"], "Done")

        self.client.post("/api/tasks", json=_task_payload("Prototype UI", status="To-Do"))

        response = self.client.get("/api/tasks?search=plan")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.get_json()), 1)

        response = self.client.get("/api/tasks?status=Done")
        self.assertEqual(response.status_code, 200)
        done_tasks = response.get_json()
        self.assertEqual(len(done_tasks), 1)
        self.assertEqual(done_tasks[0]["title"], "Plan roadmap")

        response = self.client.delete(f"/api/tasks/{created_task['id']}")
        self.assertEqual(response.status_code, 204)

    def test_blocked_tasks_must_stay_todo_until_unblocked(self) -> None:
        blocker = self.client.post("/api/tasks", json=_task_payload("Write spec")).get_json()
        blocked_response = self.client.post(
            "/api/tasks",
            json=_task_payload(
                "Build feature",
                status="In Progress",
                blocked_by_task_id=blocker["id"],
            ),
        )

        self.assertEqual(blocked_response.status_code, 400)
        self.assertEqual(blocked_response.get_json()["field"], "status")

        blocker_done = self.client.put(
            f"/api/tasks/{blocker['id']}",
            json=_task_payload("Write spec", status="Done"),
        )
        self.assertEqual(blocker_done.status_code, 200)

        blocked_ok = self.client.post(
            "/api/tasks",
            json=_task_payload(
                "Build feature",
                status="In Progress",
                blocked_by_task_id=blocker["id"],
            ),
        )
        self.assertEqual(blocked_ok.status_code, 201)

    def test_deleting_blocker_unblocks_children(self) -> None:
        blocker = self.client.post(
            "/api/tasks",
            json=_task_payload("Create API contract", status="Done"),
        ).get_json()
        child = self.client.post(
            "/api/tasks",
            json=_task_payload(
                "Build client",
                status="To-Do",
                blocked_by_task_id=blocker["id"],
            ),
        ).get_json()

        delete_response = self.client.delete(f"/api/tasks/{blocker['id']}")
        self.assertEqual(delete_response.status_code, 204)

        tasks = self.client.get("/api/tasks").get_json()
        self.assertEqual(tasks[0]["id"], child["id"])
        self.assertIsNone(tasks[0]["blockedByTaskId"])


if __name__ == "__main__":
    unittest.main()
