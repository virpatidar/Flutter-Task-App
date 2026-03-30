from __future__ import annotations

from collections.abc import Callable

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.engine import make_url
from sqlalchemy.orm import DeclarativeBase, sessionmaker


class Base(DeclarativeBase):
    pass


def create_db_engine(database_url: str) -> Engine:
    url = make_url(database_url)
    connect_args: dict[str, object] = {}

    if url.get_backend_name() == "sqlite":
        connect_args["check_same_thread"] = False

    engine = create_engine(
        database_url,
        connect_args=connect_args,
        future=True,
    )

    if url.get_backend_name() == "sqlite":
        _enable_sqlite_foreign_keys(engine)

    return engine


def create_session_factory(engine: Engine) -> Callable[[], object]:
    return sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


def create_tables(engine: Engine) -> None:
    Base.metadata.create_all(bind=engine)


def _enable_sqlite_foreign_keys(engine: Engine) -> None:
    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, _connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()
