import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';
import 'audio_service.dart';
import 'upload_service.dart';
import 'database_service.dart';
import 'api_service.dart';

class RecordingManager extends ChangeNotifier {
  final AudioService _audioService;
  final UploadService _uploadService;
  final DatabaseService _databaseService;
  final ApiService _apiService;

  List<Recording> _recordings = [];
  Timer? _statusPollTimer;
  Timer? _healthCheckTimer;

  RecordingManager(
    this._audioService,
    this._uploadService,
    this._databaseService,
    this._apiService,
  ) {
    _audioService.addListener(_onAudioServiceChanged);
    _uploadService.addListener(_onUploadServiceChanged);

    // Set up auto-stop callback for seamless segment transitions
    _audioService.onAutoStopTriggered = _handleAutoStop;

    _loadRecordings();
    // Note: checkAndResumeIfNeeded() is called from HomeScreen.didChangeAppLifecycleState
    // when app comes to foreground, not here, to avoid Android 12+ background service restrictions
    _startHealthCheck();
  }

  Future<void> checkAndResumeIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldAutoResume = prefs.getBool('auto_resume_recording') ?? true;
      final wasRecording = prefs.getBool('was_recording') ?? false;

      if (shouldAutoResume && wasRecording && !_audioService.isRecording) {
        // Wait a bit for services to initialize
        await Future.delayed(const Duration(seconds: 2));

        // Check again if not recording (user might have started manually)
        if (!_audioService.isRecording) {
          debugPrint('🔄 Auto-resuming recording after app restart/resume');
          await startRecording();
        }
      }
    } catch (e) {
      debugPrint('Error checking auto-resume: $e');
    }
  }

  Future<void> _handleAutoStop() async {
    debugPrint('🔄 Auto-stop triggered, stopping and restarting recording');
    await stopRecording(autoRestart: true);
  }

  List<Recording> get recordings => List.unmodifiable(_recordings);
  bool get isRecording => _audioService.isRecording;
  Recording? get currentRecording => _audioService.currentRecording;
  int get currentDuration => _audioService.currentDuration;
  bool get isUploading => _uploadService.isProcessing;
  double get uploadProgress => _uploadService.uploadProgress;

  void _onAudioServiceChanged() {
    notifyListeners();
  }

  void _onUploadServiceChanged() {
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    _recordings = await _databaseService.getAllRecordings();
    notifyListeners();
  }

  Future<void> startRecording({String? geminiModel}) async {
    final recording = await _audioService.startRecording(
      geminiModel: geminiModel ?? 'flash',
    );

    if (recording != null) {
      _recordings.insert(0, recording);
      await _databaseService.insertRecording(recording);

      // Track recording state for auto-resume
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('was_recording', true);

      notifyListeners();
    }
  }

  Future<void> stopRecording({bool autoRestart = false}) async {
    final recording = await _audioService.stopRecording();

    if (recording != null) {
      // Update in list
      final index = _recordings.indexWhere((r) => r.id == recording.id);
      if (index >= 0) {
        _recordings[index] = recording;
      }

      // Save to DB first
      await _databaseService.updateRecording(recording);
      notifyListeners();

      // Track recording state (only if NOT auto-restarting)
      if (!autoRestart) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('was_recording', false);
      }

      // Start next recording BEFORE queueing upload (minimizes gap)
      if (autoRestart) {
        await _autoStartNextRecording(recording.geminiModel);
      }

      // Queue upload in background (non-blocking)
      _uploadService.queueRecording(recording);
    }
  }

  Future<void> _autoStartNextRecording(String geminiModel) async {
    // Minimal delay - just enough for audio system to reset
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await startRecording(geminiModel: geminiModel);
      debugPrint('Auto-started next recording segment');
    } catch (e) {
      debugPrint('Failed to auto-start next recording: $e');
    }
  }

  // Health check timer - verify recording state every 5 minutes
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    try {
      // Check if our state matches the audio service state
      final ourState = isRecording;
      final actualState = await _audioService.isCurrentlyRecording();

      if (ourState != actualState) {
        debugPrint('⚠️ Health check: State mismatch detected! ourState=$ourState, actualState=$actualState');

        // If we think we're recording but we're not, try to restart
        if (ourState && !actualState) {
          debugPrint('🔧 Auto-restarting recording after health check failure');
          final prefs = await SharedPreferences.getInstance();
          final geminiModel = prefs.getString('default_model') ?? 'flash';

          // Reset state and restart
          _audioService.isRecording; // This will trigger a state refresh
          await startRecording(geminiModel: geminiModel);
        }
      } else {
        debugPrint('✅ Health check passed: Recording state is consistent');
      }
    } catch (e) {
      debugPrint('❌ Health check error: $e');
    }
  }

  // Poll for transcription status updates
  void startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkTranscriptionStatus();
    });
  }

  void stopStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  Future<void> _checkTranscriptionStatus() async {
    // Log all recording statuses for debugging
    final statusCounts = <String, int>{};
    for (final r in _recordings) {
      final status = r.status.toString().split('.').last;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }
    debugPrint('📊 Recording status summary: $statusCounts');

    final transcribingRecordings = _recordings.where(
      (r) => r.status == RecordingStatus.transcribing || r.status == RecordingStatus.uploaded,
    ).toList();

    debugPrint('🔍 Checking ${transcribingRecordings.length} recordings for transcription status');

    for (final recording in transcribingRecordings) {
      try {
        final apiRecording = await _apiService.getRecording(recording.id);
        if (apiRecording == null) continue;

        RecordingStatus newStatus;
        switch (apiRecording.status) {
          case 'transcribed':
            newStatus = RecordingStatus.transcribed;
            break;
          case 'failed':
            newStatus = RecordingStatus.failed;
            break;
          case 'transcribing':
            newStatus = RecordingStatus.transcribing;
            break;
          default:
            continue;
        }

        if (newStatus != recording.status || apiRecording.transcriptText != null) {
          final updated = recording.copyWith(
            status: newStatus,
            transcriptText: apiRecording.transcriptText,
            transcribedAt: apiRecording.transcribedAt,
            error: apiRecording.error,
          );

          await _databaseService.updateRecording(updated);
          final index = _recordings.indexWhere((r) => r.id == recording.id);
          if (index >= 0) {
            _recordings[index] = updated;
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error checking status for ${recording.id}: $e');
      }
    }
  }

  Future<void> retryRecording(String id) async {
    await _uploadService.retryFailed(id);
  }

  Future<void> deleteRecording(String id) async {
    await _databaseService.deleteRecording(id);
    _recordings.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  Future<void> refreshRecordings() async {
    await _loadRecordings();
    await _checkTranscriptionStatus();
  }

  Future<void> importServerRecording(ApiRecording apiRec) async {
    // Convert ApiRecording to Recording
    final recording = Recording(
      id: apiRec.id,
      startTime: apiRec.createdAt,
      endTime: apiRec.createdAt, // We don't have endTime from server
      durationSeconds: 0, // We don't have duration from server
      localPath: '', // No local file
      audioPath: null, // Will be fetched from server if needed
      status: apiRec.status == 'transcribed'
          ? RecordingStatus.transcribed
          : apiRec.status == 'transcribing'
              ? RecordingStatus.transcribing
              : apiRec.status == 'failed'
                  ? RecordingStatus.failed
                  : RecordingStatus.uploaded,
      geminiModel: 'flash',
      fileSizeBytes: 0,
      transcriptText: apiRec.transcriptText,
      createdAt: apiRec.createdAt,
      transcribedAt: apiRec.transcribedAt,
      error: apiRec.error,
    );

    await _databaseService.insertRecording(recording);
    await _loadRecordings();
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioServiceChanged);
    _audioService.onAutoStopTriggered = null;
    _uploadService.removeListener(_onUploadServiceChanged);
    stopStatusPolling();
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}
