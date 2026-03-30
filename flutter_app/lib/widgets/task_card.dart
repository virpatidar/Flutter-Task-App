import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/task.dart';
import '../models/task_status.dart';

enum TaskCardAction {
  edit,
  delete,
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.blocker,
    required this.isBlocked,
    required this.onTap,
    required this.onActionSelected,
  });

  final Task task;
  final Task? blocker;
  final bool isBlocked;
  final VoidCallback onTap;
  final ValueChanged<TaskCardAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(task.status);
    final cardGradient = _cardGradient(task.status, isBlocked);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isBlocked
                  ? Colors.white.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.ink.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: isBlocked ? AppTheme.muted : AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _InfoPill(
                              icon: Icons.calendar_today_rounded,
                              label: DateFormat('MMM d, yyyy').format(task.dueDate),
                            ),
                            _StatusPill(
                              label: task.status.label,
                              color: statusColor,
                            ),
                            if (blocker != null)
                              _InfoPill(
                                icon: isBlocked ? Icons.lock_clock_rounded : Icons.link_rounded,
                                label: isBlocked
                                    ? 'Blocked by ${blocker!.title}'
                                    : 'Depends on ${blocker!.title}',
                                tone: isBlocked ? AppTheme.blocked : AppTheme.progress,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<TaskCardAction>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    onSelected: onActionSelected,
                    itemBuilder: (context) => const [
                      PopupMenuItem<TaskCardAction>(
                        value: TaskCardAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem<TaskCardAction>(
                        value: TaskCardAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                task.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isBlocked ? AppTheme.blocked : AppTheme.muted,
                ),
              ),
              if (isBlocked) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        size: 18,
                        color: AppTheme.blocked,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This task stays visually locked until ${blocker!.title} is marked Done.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.blocked,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _cardGradient(TaskStatus status, bool isBlocked) {
    if (isBlocked) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8ECF0),
          Color(0xFFF6F8FA),
        ],
      );
    }

    if (status == TaskStatus.done) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8F8EF),
          Color(0xFFF8FFF9),
        ],
      );
    }

    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFFCF8),
        Color(0xFFFFFFFF),
      ],
    );
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.toDo:
        return AppTheme.accent;
      case TaskStatus.inProgress:
        return AppTheme.progress;
      case TaskStatus.done:
        return AppTheme.done;
    }
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.tone = AppTheme.muted,
  });

  final IconData icon;
  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
