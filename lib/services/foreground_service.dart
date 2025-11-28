import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Initialize foreground task configuration
void initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'voice_recorder_channel',
      channelName: 'Panauricon',
      channelDescription: 'Background recording',
      channelImportance: NotificationChannelImportance.MIN, // Minimal visibility
      priority: NotificationPriority.MIN,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.VISIBILITY_SECRET, // Hide from lock screen
      showWhen: false, // Hide timestamp
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000), // Update every 1 second
      autoRunOnBoot: false,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

/// Start the foreground service for recording
Future<bool> startForegroundService() async {
  if (await FlutterForegroundTask.isRunningService) {
    debugPrint('🔵 Foreground service already running');
    return true;
  }

  debugPrint('🔵 Starting foreground service');
  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'Panauricon',
    notificationText: 'Active',
    callback: startCallback,
  );

  final success = result is ServiceRequestSuccess;
  debugPrint('🔵 Foreground service start result: $success');
  return success;
}

/// Stop the foreground service
Future<bool> stopForegroundService() async {
  debugPrint('🔵 Stopping foreground service');
  final result = await FlutterForegroundTask.stopService();
  return result is ServiceRequestSuccess;
}

/// Send recording duration update to the task handler
void sendDurationUpdate(int durationSeconds, bool isRecording) {
  FlutterForegroundTask.sendDataToTask({
    'type': 'duration_update',
    'duration': durationSeconds,
    'isRecording': isRecording,
  });
}

/// Send recording stopped signal to the task handler
void sendRecordingStopped() {
  FlutterForegroundTask.sendDataToTask({
    'type': 'recording_stopped',
  });
}

/// Entry point for the foreground task isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

/// Task handler that runs in a separate isolate
/// Receives duration updates from the main app and updates the notification
class RecordingTaskHandler extends TaskHandler {
  int _currentDuration = 0;
  bool _isRecording = true;
  DateTime? _lastUpdateTime;

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter taskStarter) async {
    _currentDuration = 0;
    _isRecording = true;
    _lastUpdateTime = DateTime.now();
    debugPrint('🔵 TaskHandler: onStart');
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // If we haven't received an update recently, increment duration ourselves
    // This handles the case where the main app is suspended
    if (_isRecording) {
      final now = DateTime.now();
      if (_lastUpdateTime != null) {
        final elapsed = now.difference(_lastUpdateTime!).inSeconds;
        if (elapsed >= 2) {
          // Haven't received update in 2+ seconds, increment ourselves
          _currentDuration += 1;
        }
      }
      _lastUpdateTime = now;

      // Minimal notification - no timer
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Panauricon',
        notificationText: 'Recording',
      );
    }
  }

  @override
  void onReceiveData(Object data) async {
    if (data is Map<String, dynamic>) {
      final type = data['type'] as String?;

      switch (type) {
        case 'duration_update':
          _currentDuration = data['duration'] as int? ?? _currentDuration;
          _isRecording = data['isRecording'] as bool? ?? _isRecording;
          _lastUpdateTime = DateTime.now();

          await FlutterForegroundTask.updateService(
            notificationTitle: 'Panauricon',
            notificationText: _isRecording ? 'Recording' : 'Processing',
          );
          break;

        case 'recording_stopped':
          _isRecording = false;
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Panauricon',
            notificationText: 'Complete',
          );
          break;
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('🔵 TaskHandler: onDestroy');
  }
}
