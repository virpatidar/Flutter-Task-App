import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../models/task_draft.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TaskApiService {
  TaskApiService({
    required this.client,
    required String baseUrl,
  }) : _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  final http.Client client;
  final String _baseUrl;

  Future<List<Task>> fetchTasks() async {
    final response = await client.get(_buildUri('/tasks'));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Task.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Task> createTask(TaskDraft draft) async {
    final response = await client.post(
      _buildUri('/tasks'),
      headers: _jsonHeaders,
      body: jsonEncode(draft.toApiJson()),
    );
    _ensureSuccess(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Task> updateTask(int taskId, TaskDraft draft) async {
    final response = await client.put(
      _buildUri('/tasks/$taskId'),
      headers: _jsonHeaders,
      body: jsonEncode(draft.toApiJson()),
    );
    _ensureSuccess(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTask(int taskId) async {
    final response = await client.delete(_buildUri('/tasks/$taskId'));
    _ensureSuccess(response);
  }

  Map<String, String> get _jsonHeaders => const {
        'Content-Type': 'application/json',
      };

  Uri _buildUri(String path) => Uri.parse('$_baseUrl$path');

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw ApiException(_extractMessage(response));
  }

  String _extractMessage(http.Response response) {
    if (response.body.isEmpty) {
      return 'Something went wrong (${response.statusCode}).';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      return 'Something went wrong (${response.statusCode}).';
    }

    return 'Something went wrong (${response.statusCode}).';
  }
}
