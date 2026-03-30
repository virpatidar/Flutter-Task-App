enum TaskStatus {
  toDo('To-Do'),
  inProgress('In Progress'),
  done('Done');

  const TaskStatus(this.label);

  final String label;

  static TaskStatus fromLabel(String value) {
    return TaskStatus.values.firstWhere(
      (status) => status.label == value,
      orElse: () => TaskStatus.toDo,
    );
  }
}
