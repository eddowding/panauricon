import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/recording.dart';
import 'foreground_service.dart';

class AudioService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  Recording? _currentRecording;
  Timer? _durationTimer;
  Timer? _autoStopTimer;
  bool _isRecording = false;
  bool _isStarting = false; // Mutex to prevent concurrent start calls
  int _currentDuration = 0;

  // Callback for when auto-stop timer fires (so RecordingManager can restart)
  Future<void> Function()? onAutoStopTriggered;

  bool get isRecording => _isRecording;
  Recording? get currentRecording => _currentRecording;
  int get currentDuration => _currentDuration;

  Future<bool> checkPermissions() async {
    final micStatus = await Permission.microphone.request();
    final notificationStatus = await Permission.notification.request();

    return micStatus.isGranted && notificationStatus.isGranted;
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  Future<Recording?> startRecording({String geminiModel = 'flash'}) async {
    debugPrint('🎤 startRecording called! isRecording=$_isRecording, isStarting=$_isStarting');

    // Mutex: prevent concurrent startRecording calls
    if (_isRecording || _isStarting) {
      debugPrint('🎤 Already recording or starting, returning null');
      return null;
    }

    _isStarting = true;

    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        _isStarting = false;
        throw Exception('Microphone permission not granted');
      }

      final directory = await getApplicationDocumentsDirectory();
      final id = const Uuid().v4();
      final timestamp = DateTime.now();
      final filePath = '${directory.path}/recording_$id.m4a';

      // Get location
      final position = await _getCurrentLocation();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: AppConfig.audioBitrate,
          sampleRate: AppConfig.sampleRate,
          numChannels: 1,
        ),
        path: filePath,
      );

      _currentRecording = Recording(
        id: id,
        startTime: timestamp,
        durationSeconds: 0,
        localPath: filePath,
        status: RecordingStatus.recording,
        geminiModel: geminiModel,
        latitude: position?.latitude,
        longitude: position?.longitude,
        fileSizeBytes: 0,
        createdAt: timestamp,
      );

      _isRecording = true;
      _isStarting = false;
      _currentDuration = 0;
      _startDurationTimer();
      _scheduleAutoStop();
      notifyListeners();

      return _currentRecording;
    } catch (e) {
      _isStarting = false;
      debugPrint('Error starting recording: $e');
      rethrow;
    }
  }

  void _startDurationTimer() {
    // Cancel any existing timer first (safety measure)
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _currentDuration++;
      if (_currentRecording != null) {
        _currentRecording = _currentRecording!.copyWith(
          durationSeconds: _currentDuration,
        );

        // Send duration update to foreground service every second
        sendDurationUpdate(_currentDuration, true);

        // Log every 30 seconds to track recording continuity
        if (_currentDuration % 30 == 0) {
          final isActuallyRecording = await _recorder.isRecording();
          debugPrint('📍 Recording tick: ${_currentDuration}s | isRecording: $isActuallyRecording');
        }
        notifyListeners();
      }
    });
  }

  /// Calculate seconds until the next clock-aligned segment boundary
  /// For 30-minute segments: stops at :00 or :30
  int _secondsUntilNextBoundary() {
    final now = DateTime.now();
    final segmentMinutes = AppConfig.segmentDurationMinutes;

    // Find current segment number within the hour
    final currentMinute = now.minute;
    final currentSecond = now.second;

    // Calculate which segment boundary we're heading toward
    int nextBoundaryMinute;
    if (currentMinute < segmentMinutes) {
      nextBoundaryMinute = segmentMinutes; // e.g., 30
    } else {
      nextBoundaryMinute = 60; // Top of next hour
    }

    // Calculate seconds until that boundary
    final minutesUntil = nextBoundaryMinute - currentMinute;
    final secondsUntil = (minutesUntil * 60) - currentSecond;

    // If we're exactly at a boundary, schedule for the next one
    if (secondsUntil <= 0) {
      return segmentMinutes * 60;
    }

    return secondsUntil;
  }

  void _scheduleAutoStop() {
    // Cancel any existing auto-stop timer first (safety measure)
    _autoStopTimer?.cancel();

    final secondsUntilBoundary = _secondsUntilNextBoundary();
    final boundaryTime = DateTime.now().add(Duration(seconds: secondsUntilBoundary));

    debugPrint('📍 Recording will auto-stop at ${boundaryTime.hour.toString().padLeft(2, '0')}:${boundaryTime.minute.toString().padLeft(2, '0')} (in ${secondsUntilBoundary}s)');

    _autoStopTimer = Timer(
      Duration(seconds: secondsUntilBoundary),
      () async {
        final now = DateTime.now();
        debugPrint('⏰ Auto-stop triggered at clock boundary ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

        // Use callback if provided (RecordingManager handles stop + restart)
        if (onAutoStopTriggered != null) {
          await onAutoStopTriggered!();
        } else {
          // Fallback: just stop without restart
          await stopRecording();
        }
      },
    );
  }

  Future<Recording?> stopRecording() async {
    // Debug: Log who's calling stopRecording
    debugPrint('🛑 stopRecording called! isRecording=$_isRecording, currentRecording=${_currentRecording?.id}');
    debugPrint('🛑 Stack trace: ${StackTrace.current.toString().split('\n').take(10).join('\n')}');

    if (!_isRecording || _currentRecording == null) {
      debugPrint('🛑 stopRecording: Early return - nothing to stop');
      return null;
    }

    try {
      debugPrint('🛑 Actually stopping recorder...');
      final path = await _recorder.stop();
      _durationTimer?.cancel();
      _autoStopTimer?.cancel();

      // Signal foreground service that recording stopped
      sendRecordingStopped();

      if (path != null) {
        final file = File(path);
        final fileSize = await file.length();

        final completedRecording = _currentRecording!.copyWith(
          endTime: DateTime.now(),
          durationSeconds: _currentDuration,
          status: RecordingStatus.pending,
          fileSizeBytes: fileSize,
        );

        _currentRecording = null;
        _isRecording = false;
        _currentDuration = 0;
        notifyListeners();

        return completedRecording;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      rethrow;
    }

    return null;
  }

  Future<bool> isCurrentlyRecording() async {
    return await _recorder.isRecording();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _autoStopTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
