import 'task.dart';
import 'task_status.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.blockedByTaskId,
  });

  final String title;
  final String description;
  final DateTime? dueDate;
  final TaskStatus status;
  final int? blockedByTaskId;

  factory TaskDraft.empty() {
    return TaskDraft(
      title: '',
      description: '',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      status: TaskStatus.toDo,
      blockedByTaskId: null,
    );
  }

  factory TaskDraft.fromTask(Task task) {
    return TaskDraft(
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      status: task.status,
      blockedByTaskId: task.blockedByTaskId,
    );
  }

  factory TaskDraft.fromStorageJson(Map<String, dynamic> json) {
    return TaskDraft(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      status: TaskStatus.fromLabel(
        json['status'] as String? ?? TaskStatus.toDo.label,
      ),
      blockedByTaskId: json['blockedByTaskId'] as int?,
    );
  }

  bool get isMeaningful {
    return title.trim().isNotEmpty ||
        description.trim().isNotEmpty ||
        blockedByTaskId != null ||
        status != TaskStatus.toDo;
  }

  Map<String, dynamic> toApiJson() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'dueDate': dueDate == null ? null : _serializeDate(dueDate!),
      'status': status.label,
      'blockedByTaskId': blockedByTaskId,
    };
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate == null ? null : _serializeDate(dueDate!),
      'status': status.label,
      'blockedByTaskId': blockedByTaskId,
    };
  }

  static String _serializeDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    return normalized.toIso8601String().split('T').first;
  }
}
