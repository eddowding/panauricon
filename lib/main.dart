import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'services/audio_service.dart';
import 'services/upload_service.dart';
import 'services/database_service.dart';
import 'services/api_service.dart';
import 'services/recording_manager.dart';
import 'services/foreground_service.dart';
import 'services/theme_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize foreground task
  initForegroundTask();

  runApp(const VoiceRecorderApp());
}

class VoiceRecorderApp extends StatelessWidget {
  const VoiceRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core services
        Provider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => AudioService()),

        // Theme service (needs initialization)
        ChangeNotifierProvider(create: (_) {
          final service = ThemeService();
          service.init();
          return service;
        }),

        // API service (needs initialization)
        ChangeNotifierProvider(create: (_) {
          final service = ApiService();
          service.init();
          return service;
        }),

        // Upload service (depends on API and Database)
        ChangeNotifierProxyProvider2<ApiService, DatabaseService, UploadService>(
          create: (context) => UploadService(
            context.read<ApiService>(),
            context.read<DatabaseService>(),
          ),
          update: (context, api, db, previous) {
            if (previous == null) {
              final service = UploadService(api, db);
              service.startMonitoring();
              return service;
            }
            return previous;
          },
        ),

        // Recording manager (orchestrates everything)
        ChangeNotifierProxyProvider4<AudioService, UploadService, DatabaseService,
            ApiService, RecordingManager>(
          create: (context) => RecordingManager(
            context.read<AudioService>(),
            context.read<UploadService>(),
            context.read<DatabaseService>(),
            context.read<ApiService>(),
          ),
          update: (context, audio, upload, db, api, previous) =>
              previous ??
              RecordingManager(audio, upload, db, api),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return WithForegroundTask(
            child: MaterialApp(
              title: 'Voice Recorder',
              debugShowCheckedModeBanner: false,
              themeMode: themeService.themeMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blue,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              home: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
