from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(slots=True)
class AppConfig:
    database_url: str
    debug: bool = False

    @classmethod
    def from_env(cls, database_url: str | None = None) -> "AppConfig":
        default_db_path = Path(__file__).resolve().parents[1] / "task_manager.db"
        resolved_database_url = (
            database_url
            or os.getenv("TASK_API_DATABASE_URL")
            or f"sqlite:///{default_db_path.as_posix()}"
        )
        debug_flag = os.getenv("FLASK_DEBUG", "0") == "1"
        return cls(database_url=resolved_database_url, debug=debug_flag)
