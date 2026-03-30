import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/task_list_screen.dart';
import 'services/draft_storage_service.dart';
import 'services/task_api_service.dart';
import 'services/task_repository.dart';
import 'state/task_list_controller.dart';

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<http.Client>(
          create: (_) => http.Client(),
          dispose: (_, client) => client.close(),
        ),
        Provider<TaskRepository>(
          create: (context) => TaskRepository(
            apiService: TaskApiService(
              client: context.read<http.Client>(),
              baseUrl: AppConfig.apiBaseUrl,
            ),
          ),
        ),
        Provider<DraftStorageService>(
          create: (_) => const DraftStorageService(),
        ),
        ChangeNotifierProvider<TaskListController>(
          create: (context) => TaskListController(
            repository: context.read<TaskRepository>(),
          )..loadTasks(),
        ),
      ],
      child: MaterialApp(
        title: 'Task Flow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const TaskListScreen(),
      ),
    );
  }
}
