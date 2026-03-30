import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/task.dart';
import '../models/task_draft.dart';
import '../models/task_status.dart';
import '../services/draft_storage_service.dart';
import '../services/task_api_service.dart';
import '../services/task_repository.dart';
import '../widgets/app_backdrop.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    this.existingTask,
  });

  final Task? existingTask;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TaskRepository _repository;
  late final DraftStorageService _draftStorage;

  DateTime? _dueDate;
  TaskStatus _status = TaskStatus.toDo;
  int? _blockedByTaskId;

  List<Task> _availableTasks = <Task>[];
  bool _isBootstrapping = true;
  bool _isSaving = false;
  bool _restoredDraft = false;
  String? _errorMessage;
  Timer? _draftTimer;

  bool get _isEditing => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _repository = context.read<TaskRepository>();
    _draftStorage = context.read<DraftStorageService>();

    final seed = widget.existingTask == null
        ? TaskDraft.empty()
        : TaskDraft.fromTask(widget.existingTask!);

    _titleController = TextEditingController(text: seed.title);
    _descriptionController = TextEditingController(text: seed.description);
    _dueDate = seed.dueDate;
    _status = seed.status;
    _blockedByTaskId = seed.blockedByTaskId;

    _titleController.addListener(_scheduleDraftSave);
    _descriptionController.addListener(_scheduleDraftSave);

    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    if (!_isEditing) {
      unawaited(_persistDraft());
    }
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isEditing) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraft());
    }
  }

  Future<void> _bootstrap() async {
    try {
      final tasks = await _repository.fetchTasks();
      final restoredDraft = _isEditing ? null : await _draftStorage.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _availableTasks = tasks
            .where((task) => task.id != widget.existingTask?.id)
            .toList(growable: false);

        if (restoredDraft != null) {
          _titleController.text = restoredDraft.title;
          _descriptionController.text = restoredDraft.description;
          _dueDate = restoredDraft.dueDate ?? _dueDate;
          _status = restoredDraft.status;
          _blockedByTaskId = restoredDraft.blockedByTaskId;
          _restoredDraft = restoredDraft.isMeaningful;
        }

        if (_blockedByTaskId != null &&
            !_availableTasks.any((task) => task.id == _blockedByTaskId)) {
          _blockedByTaskId = null;
        }

        _coerceInvalidBlockedState(showMessage: false);
        _isBootstrapping = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
        _errorMessage = 'Unable to load task dependencies right now.';
      });
    }
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_dueDate == null) {
      setState(() {
        _errorMessage = 'Please choose a due date before saving.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final payload = TaskDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      dueDate: _dueDate,
      status: _status,
      blockedByTaskId: _blockedByTaskId,
    );

    try {
      if (_isEditing) {
        await _repository.updateTask(widget.existingTask!.id, payload);
      } else {
        await _repository.createTask(payload);
        await _draftStorage.clear();
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to save the task right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDueDate() async {
    final initialDate = _dueDate ?? DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dueDate = picked;
    });
    _scheduleDraftSave();
  }

  Future<void> _persistDraft() async {
    if (_isEditing) {
      return;
    }

    final draft = TaskDraft(
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate,
      status: _status,
      blockedByTaskId: _blockedByTaskId,
    );

    await _draftStorage.save(draft);
  }

  void _scheduleDraftSave() {
    if (_isEditing) {
      return;
    }

    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistDraft());
    });
  }

  void _onStatusChanged(TaskStatus? value) {
    if (value == null) {
      return;
    }

    if (_selectedBlocker != null &&
        _selectedBlocker!.status != TaskStatus.done &&
        value != TaskStatus.toDo) {
      _showMessage('Blocked tasks must stay in To-Do until the blocker is Done.');
      return;
    }

    setState(() {
      _status = value;
    });
    _scheduleDraftSave();
  }

  void _onBlockedByChanged(int? value) {
    setState(() {
      _blockedByTaskId = value;
      _coerceInvalidBlockedState(showMessage: true);
    });
    _scheduleDraftSave();
  }

  void _coerceInvalidBlockedState({required bool showMessage}) {
    final blocker = _selectedBlocker;
    if (blocker == null) {
      return;
    }

    if (blocker.status != TaskStatus.done && _status != TaskStatus.toDo) {
      _status = TaskStatus.toDo;
      if (showMessage) {
        _showMessage('Status reset to To-Do because the selected blocker is not Done yet.');
      }
    }
  }

  Task? get _selectedBlocker {
    final blockerId = _blockedByTaskId;
    if (blockerId == null) {
      return null;
    }

    for (final task in _availableTasks) {
      if (task.id == blockerId) {
        return task;
      }
    }

    return null;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: AbsorbPointer(
            absorbing: _isSaving,
            child: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _RoundIconButton(
                                  icon: Icons.arrow_back_rounded,
                                  onPressed: () => Navigator.of(context).maybePop(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isEditing ? 'Edit Task' : 'Create Task',
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _isEditing
                                            ? 'Update details, dependencies, or status.'
                                            : 'Drafts stay here if you leave before saving.',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.76),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white.withOpacity(0.88)),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_restoredDraft && !_isEditing) ...[
                                      _InlineNotice(
                                        icon: Icons.auto_awesome_rounded,
                                        message: 'Your last draft was restored.',
                                        tone: AppTheme.progress,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (_selectedBlocker != null &&
                                        _selectedBlocker!.status != TaskStatus.done) ...[
                                      _InlineNotice(
                                        icon: Icons.lock_clock_rounded,
                                        message:
                                            'This task depends on ${_selectedBlocker!.title}. Status is locked to To-Do until that task is Done.',
                                        tone: AppTheme.blocked,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (_errorMessage != null) ...[
                                      _InlineNotice(
                                        icon: Icons.error_outline_rounded,
                                        message: _errorMessage!,
                                        tone: const Color(0xFFC23B33),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    TextFormField(
                                      controller: _titleController,
                                      textInputAction: TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Title',
                                        hintText: 'Sprint planning',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Title is required.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _descriptionController,
                                      minLines: 5,
                                      maxLines: 7,
                                      textInputAction: TextInputAction.newline,
                                      decoration: const InputDecoration(
                                        labelText: 'Description',
                                        hintText: 'Summarize the work, expected outcome, and notes.',
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Description is required.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Due Date',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: _pickDueDate,
                                      borderRadius: BorderRadius.circular(24),
                                      child: Ink(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 18,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.72),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(color: AppTheme.border),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.event_rounded),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                _dueDate == null
                                                    ? 'Select a due date'
                                                    : DateFormat('EEEE, MMM d, yyyy').format(
                                                        _dueDate!,
                                                      ),
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  color: _dueDate == null
                                                      ? AppTheme.muted
                                                      : AppTheme.ink,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    DropdownButtonFormField<TaskStatus>(
                                      value: _status,
                                      decoration: const InputDecoration(
                                        labelText: 'Status',
                                        prefixIcon: Icon(Icons.flag_rounded),
                                      ),
                                      items: TaskStatus.values
                                          .map(
                                            (status) => DropdownMenuItem<TaskStatus>(
                                              value: status,
                                              child: Text(status.label),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: _onStatusChanged,
                                    ),
                                    const SizedBox(height: 18),
                                    DropdownButtonFormField<int?>(
                                      value: _availableTasks.any((task) => task.id == _blockedByTaskId)
                                          ? _blockedByTaskId
                                          : null,
                                      decoration: const InputDecoration(
                                        labelText: 'Blocked By',
                                        prefixIcon: Icon(Icons.account_tree_rounded),
                                      ),
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('No blocker'),
                                        ),
                                        ..._availableTasks.map(
                                          (task) => DropdownMenuItem<int?>(
                                            value: task.id,
                                            child: Text('${task.title} (${task.status.label})'),
                                          ),
                                        ),
                                      ],
                                      onChanged: _isBootstrapping ? null : _onBlockedByChanged,
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _isBootstrapping ? null : _submit,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                        ),
                                        icon: _isSaving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Icon(
                                                _isEditing
                                                    ? Icons.save_rounded
                                                    : Icons.add_task_rounded,
                                              ),
                                        label: Text(_isEditing ? 'Save Changes' : 'Create Task'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isBootstrapping)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withOpacity(0.25),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppTheme.accent,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Loading task details...'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
