import '../models/task.dart';
import '../models/task_draft.dart';
import 'task_api_service.dart';

class TaskRepository {
  const TaskRepository({
    required TaskApiService apiService,
  }) : _apiService = apiService;

  final TaskApiService _apiService;

  Future<List<Task>> fetchTasks() => _apiService.fetchTasks();

  Future<Task> createTask(TaskDraft draft) => _apiService.createTask(draft);

  Future<Task> updateTask(int taskId, TaskDraft draft) => _apiService.updateTask(taskId, draft);

  Future<void> deleteTask(int taskId) => _apiService.deleteTask(taskId);
}
