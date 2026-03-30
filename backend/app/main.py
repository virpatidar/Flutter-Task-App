from __future__ import annotations

from http import HTTPStatus
from typing import Any

from flask import Flask, g, jsonify, request

from .config import AppConfig
from .database import create_db_engine, create_session_factory, create_tables
from .repository import create_task, delete_task, list_tasks, update_task
from .schemas import ApiError, parse_task_payload, serialize_task


def create_app(database_url: str | None = None) -> Flask:
    config = AppConfig.from_env(database_url)
    app = Flask(__name__)

    engine = create_db_engine(config.database_url)
    session_factory = create_session_factory(engine)
    create_tables(engine)

    app.config["DEBUG"] = config.debug
    app.config["SESSION_FACTORY"] = session_factory

    @app.before_request
    def open_db_session() -> None:
        g.db = session_factory()

    @app.teardown_request
    def close_db_session(_exception: BaseException | None) -> None:
        db = getattr(g, "db", None)
        if db is not None:
            db.close()

    @app.after_request
    def add_cors_headers(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
        return response

    @app.errorhandler(ApiError)
    def handle_api_error(error: ApiError):
        payload: dict[str, Any] = {"message": error.message}
        if error.field:
            payload["field"] = error.field
        return jsonify(payload), error.status_code

    @app.errorhandler(HTTPStatus.NOT_FOUND)
    def handle_not_found(_error):
        return jsonify({"message": "Route not found."}), HTTPStatus.NOT_FOUND

    @app.get("/api/health")
    def healthcheck():
        return jsonify({"status": "ok"})

    @app.route("/api/tasks", methods=["OPTIONS"])
    @app.route("/api/tasks/<int:task_id>", methods=["OPTIONS"])
    def options_handler(task_id: int | None = None):
        return ("", HTTPStatus.NO_CONTENT)

    @app.get("/api/tasks")
    def get_tasks():
        tasks = list_tasks(
            g.db,
            search=request.args.get("search"),
            status=request.args.get("status"),
        )
        return jsonify([serialize_task(task) for task in tasks])

    @app.post("/api/tasks")
    def post_task():
        payload = parse_task_payload(request.get_json(silent=True))
        task = create_task(g.db, payload)
        return jsonify(serialize_task(task)), HTTPStatus.CREATED

    @app.put("/api/tasks/<int:task_id>")
    def put_task(task_id: int):
        payload = parse_task_payload(request.get_json(silent=True))
        task = update_task(g.db, task_id, payload)
        return jsonify(serialize_task(task))

    @app.delete("/api/tasks/<int:task_id>")
    def remove_task(task_id: int):
        delete_task(g.db, task_id)
        return ("", HTTPStatus.NO_CONTENT)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
