import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../state/task_list_controller.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/task_card.dart';
import '../widgets/task_empty_state.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskListController>(
      builder: (context, controller, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AppBackdrop(
            child: SafeArea(
              child: RefreshIndicator(
                color: AppTheme.accent,
                onRefresh: controller.loadTasks,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Task Flow',
                                        style: Theme.of(context).textTheme.headlineMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Plan, track, and unblock work with a dependency-aware workflow.',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: AppTheme.muted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: IconButton(
                                    onPressed: () => controller.loadTasks(),
                                    icon: controller.isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2.4),
                                          )
                                        : const Icon(Icons.sync_rounded),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            _StatsRow(
                              totalCount: controller.totalCount,
                              blockedCount: controller.blockedCount,
                              completedCount: controller.completedCount,
                            ),
                            const SizedBox(height: 18),
                            _ControlPanel(
                              controller: _searchController,
                              selectedStatus: controller.filterStatus,
                              onSearchChanged: controller.updateSearchQuery,
                              onStatusChanged: controller.updateFilter,
                            ),
                            if (controller.errorMessage != null) ...[
                              const SizedBox(height: 18),
                              _ErrorBanner(
                                message: controller.errorMessage!,
                                onRetry: controller.loadTasks,
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    if (controller.isLoading && controller.allTasks.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: AppTheme.accent),
                        ),
                      )
                    else if (controller.visibleTasks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                          child: Center(
                            child: TaskEmptyState(
                              title: controller.allTasks.isEmpty
                                  ? 'No tasks yet'
                                  : 'No matching tasks',
                              message: controller.allTasks.isEmpty
                                  ? 'Start with your first task and build momentum from there.'
                                  : 'Try a different search term or reset the status filter.',
                              onAction: controller.allTasks.isEmpty
                                  ? () => _openTaskForm(context)
                                  : null,
                              actionLabel: controller.allTasks.isEmpty ? 'Create Task' : null,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final itemIndex = index ~/ 2;
                              if (index.isOdd) {
                                return const SizedBox(height: 14);
                              }

                              final task = controller.visibleTasks[itemIndex];
                              final blocker = controller.blockerFor(task);

                              return TaskCard(
                                task: task,
                                blocker: blocker,
                                isBlocked: controller.isTaskBlocked(task),
                                onTap: () => _openTaskForm(context, task: task),
                                onActionSelected: (action) {
                                  switch (action) {
                                    case TaskCardAction.edit:
                                      _openTaskForm(context, task: task);
                                      break;
                                    case TaskCardAction.delete:
                                      _confirmDelete(context, task: task);
                                      break;
                                  }
                                },
                              );
                            },
                            childCount: controller.visibleTasks.isEmpty
                                ? 0
                                : controller.visibleTasks.length * 2 - 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openTaskForm(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task'),
          ),
        );
      },
    );
  }

  Future<void> _openTaskForm(BuildContext context, {Task? task}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(existingTask: task),
      ),
    );

    if (!context.mounted || saved != true) {
      return;
    }

    await context.read<TaskListController>().loadTasks();
    if (!context.mounted) {
      return;
    }

    final label = task == null ? 'Task created.' : 'Task updated.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _confirmDelete(BuildContext context, {required Task task}) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text(
            '"${task.title}" will be removed. Any tasks blocked by it become unblocked automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC23B33),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || shouldDelete != true) {
      return;
    }

    final deleted = await context.read<TaskListController>().deleteTask(task.id);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted ? 'Task deleted.' : 'Unable to delete the task.',
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalCount,
    required this.blockedCount,
    required this.completedCount,
  });

  final int totalCount;
  final int blockedCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'Total',
            value: totalCount.toString(),
            tint: AppTheme.accentSoft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Blocked',
            value: blockedCount.toString(),
            tint: const Color(0xFFD9E1EA),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            label: 'Done',
            value: completedCount.toString(),
            tint: const Color(0xFFD9F1E3),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 6,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.controller,
    required this.selectedStatus,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final TaskStatus? selectedStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TaskStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by title',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<TaskStatus?>(
            value: selectedStatus,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_alt_rounded),
              labelText: 'Filter by status',
            ),
            items: [
              const DropdownMenuItem<TaskStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...TaskStatus.values.map(
                (status) => DropdownMenuItem<TaskStatus?>(
                  value: status,
                  child: Text(status.label),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEE9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC23B33)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message),
          ),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
