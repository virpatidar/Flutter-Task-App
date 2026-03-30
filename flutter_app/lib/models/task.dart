import 'task_status.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.blockedByTaskId,
  });

  final int id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final int? blockedByTaskId;

  bool get isDone => status == TaskStatus.done;

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskStatus? status,
    int? blockedByTaskId,
    bool clearBlockedByTaskId = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      blockedByTaskId: clearBlockedByTaskId ? null : blockedByTaskId ?? this.blockedByTaskId,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: DateTime.parse(json['dueDate'] as String),
      status: TaskStatus.fromLabel(json['status'] as String),
      blockedByTaskId: json['blockedByTaskId'] as int?,
    );
  }
}
