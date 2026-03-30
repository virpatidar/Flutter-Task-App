import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_draft.dart';

class DraftStorageService {
  const DraftStorageService();

  static const String _newTaskDraftKey = 'new_task_draft_v1';

  Future<TaskDraft?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_newTaskDraftKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return TaskDraft.fromStorageJson(decoded);
    } catch (_) {
      await preferences.remove(_newTaskDraftKey);
      return null;
    }
  }

  Future<void> save(TaskDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    if (!draft.isMeaningful) {
      await preferences.remove(_newTaskDraftKey);
      return;
    }

    await preferences.setString(_newTaskDraftKey, jsonEncode(draft.toStorageJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_newTaskDraftKey);
  }
}
