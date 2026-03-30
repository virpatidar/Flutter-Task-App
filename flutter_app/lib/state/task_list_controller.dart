import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_status.dart';
import '../services/task_api_service.dart';
import '../services/task_repository.dart';

class TaskListController extends ChangeNotifier {
  TaskListController({
    required TaskRepository repository,
  }) : _repository = repository;

  final TaskRepository _repository;

  final List<Task> _tasks = <Task>[];

  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  TaskStatus? _filterStatus;

  List<Task> get allTasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  TaskStatus? get filterStatus => _filterStatus;

  int get totalCount => _tasks.length;

  int get completedCount {
    return _tasks.where((task) => task.status == TaskStatus.done).length;
  }

  int get blockedCount {
    return _tasks.where(isTaskBlocked).length;
  }

  List<Task> get visibleTasks {
    Iterable<Task> filtered = _tasks;

    final normalizedSearch = _searchQuery.trim().toLowerCase();
    if (normalizedSearch.isNotEmpty) {
      filtered = filtered.where(
        (task) => task.title.toLowerCase().contains(normalizedSearch),
      );
    }

    if (_filterStatus != null) {
      filtered = filtered.where((task) => task.status == _filterStatus);
    }

    return List.unmodifiable(filtered);
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final tasks = await _repository.fetchTasks();
      _tasks
        ..clear()
        ..addAll(tasks);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Unable to reach the task API. Check that the backend is running.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTask(int taskId) async {
    try {
      await _repository.deleteTask(taskId);
      _errorMessage = null;
      final updatedTasks = _tasks
          .where((task) => task.id != taskId)
          .map(
            (task) => task.blockedByTaskId == taskId
                ? task.copyWith(clearBlockedByTaskId: true)
                : task,
          )
          .toList(growable: false);
      _tasks
        ..clear()
        ..addAll(updatedTasks);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to delete the task right now.';
      notifyListeners();
      return false;
    }
  }

  void updateSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void updateFilter(TaskStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  Task? blockerFor(Task task) {
    final blockerId = task.blockedByTaskId;
    if (blockerId == null) {
      return null;
    }

    for (final candidate in _tasks) {
      if (candidate.id == blockerId) {
        return candidate;
      }
    }

    return null;
  }

  bool isTaskBlocked(Task task) {
    final blocker = blockerFor(task);
    return blocker != null && blocker.status != TaskStatus.done;
  }
}
