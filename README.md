# Flutter-Task-App
This is task app that can used for adding the tasks and time of working for remember.
# Task Flow

Task Flow is a full-stack task management assignment implementation with:

- A Flutter client in `flutter_app/`
- A Flask + SQLite REST API in `backend/`

## Highlights

- CRUD task management
- Search by title and filter by status
- Dependency-aware `Blocked By` relationships
- Muted, visibly distinct cards for tasks blocked by incomplete work
- Persistent new-task drafts using local device storage
- Clean separation between UI, state, repository, and API layers

## Backend

### Run

```bash
cd backend
python -m app.main
```

The API starts at `http://127.0.0.1:8000`.

### Test

```bash
python -m unittest discover -s backend/tests
```

## Flutter App

### Run

```bash
cd flutter_app
flutter pub get
flutter run
```

The app expects the backend at:

- `http://10.0.2.2:8000/api` on Android emulators
- `http://127.0.0.1:8000/api` elsewhere

Override it if needed:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_HOST:8000/api
```

### Important note

The Flutter SDK is not installed in this workspace, so the native runner folders were not generated here. If you want the standard Android/iOS/web/desktop shell files created locally, run this once inside `flutter_app/`:

```bash
flutter create .
```

That keeps the app code in `lib/` and `pubspec.yaml` intact while generating the platform scaffolding.

## API Contract

### Task shape

```json
{
  "id": 1,
  "title": "Sprint planning",
  "description": "Prepare the backlog and align owners.",
  "dueDate": "2026-04-15",
  "status": "To-Do",
  "blockedByTaskId": null
}
```

### Endpoints

- `GET /api/health`
- `GET /api/tasks`
- `POST /api/tasks`
- `PUT /api/tasks/:id`
- `DELETE /api/tasks/:id`

## Architecture Notes

- The backend enforces dependency rules and prevents circular blockers.
- If a blocker task is deleted, dependent tasks are automatically unblocked.
- The Flutter list screen keeps all tasks in memory so blocked styling still works even when search/filter hides the blocker from the visible list.
- Drafts are restored automatically when users reopen the create-task flow after leaving it mid-entry.
