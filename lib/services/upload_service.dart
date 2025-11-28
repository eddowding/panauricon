import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/recording.dart';
import 'api_service.dart';
import 'database_service.dart';

class UploadService extends ChangeNotifier {
  final ApiService _apiService;
  final DatabaseService _databaseService;
  final Connectivity _connectivity = Connectivity();

  bool _isProcessing = false;
  String? _currentUploadId;
  double _uploadProgress = 0.0;
  StreamSubscription? _connectivitySubscription;
  bool _wifiOnlyUpload = true; // Default to WiFi-only

  UploadService(this._apiService, this._databaseService);

  bool get wifiOnlyUpload => _wifiOnlyUpload;

  set wifiOnlyUpload(bool value) {
    _wifiOnlyUpload = value;
    notifyListeners();
    // Try to process queue if we just enabled mobile upload and have connection
    if (!value) {
      processUploadQueue();
    }
  }

  bool get isProcessing => _isProcessing;
  String? get currentUploadId => _currentUploadId;
  double get uploadProgress => _uploadProgress;

  void startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (hasConnection && !_isProcessing) {
          processUploadQueue();
        }
      },
    );
  }

  void stopMonitoring() {
    _connectivitySubscription?.cancel();
  }

  Future<bool> hasInternetConnection() async {
    final results = await _connectivity.checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (!hasConnection) return false;

    // If WiFi-only is enabled, check specifically for WiFi
    if (_wifiOnlyUpload) {
      final hasWifi = results.contains(ConnectivityResult.wifi);
      if (!hasWifi) {
        debugPrint('Upload skipped: WiFi-only mode enabled, not on WiFi');
        return false;
      }
    }

    return true;
  }

  Future<bool> isOnWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  Future<void> queueRecording(Recording recording) async {
    // Save recording to database
    await _databaseService.insertRecording(recording);
    await _databaseService.addToUploadQueue(recording.id);

    // Try to process immediately if online
    if (await hasInternetConnection()) {
      processUploadQueue();
    }
  }

  /// Calculate exponential backoff delay in seconds: 1min, 5min, 15min, 1hr
  int _calculateBackoffDelay(int attempts) {
    if (attempts <= 0) return 0;
    if (attempts == 1) return 60; // 1 minute
    if (attempts == 2) return 300; // 5 minutes
    if (attempts == 3) return 900; // 15 minutes
    return 3600; // 1 hour for 4+ attempts
  }

  /// Check if a recording is ready to retry based on backoff delay
  Future<bool> _isReadyToRetry(String recordingId) async {
    final attemptInfo = await _databaseService.getUploadAttempts(recordingId);
    if (attemptInfo == null) return true;

    final attempts = attemptInfo['attempts'] as int;
    final lastAttemptStr = attemptInfo['lastAttempt'] as String?;

    // First attempt or no previous attempt time
    if (attempts == 0 || lastAttemptStr == null) return true;

    final lastAttempt = DateTime.parse(lastAttemptStr);
    final backoffSeconds = _calculateBackoffDelay(attempts);
    final nextRetryTime = lastAttempt.add(Duration(seconds: backoffSeconds));

    final isReady = DateTime.now().isAfter(nextRetryTime);
    if (!isReady) {
      final remainingSeconds = nextRetryTime.difference(DateTime.now()).inSeconds;
      debugPrint(
          '⏳ Upload backoff: Retry in ${remainingSeconds}s (attempt $attempts)');
    }
    return isReady;
  }

  Future<void> processUploadQueue() async {
    if (_isProcessing) return;
    if (_apiService.apiKey == null) {
      debugPrint('No API key configured, skipping upload');
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final pendingRecordings = await _databaseService.getPendingUploads();

      for (final recording in pendingRecordings) {
        if (!await hasInternetConnection()) {
          debugPrint('Lost connection, pausing uploads');
          break;
        }

        // Check if recording is ready to retry based on exponential backoff
        if (!await _isReadyToRetry(recording.id)) {
          continue;
        }

        await _uploadRecording(recording);
      }
    } catch (e) {
      debugPrint('Error processing upload queue: $e');
    } finally {
      _isProcessing = false;
      _currentUploadId = null;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  Future<void> _uploadRecording(Recording recording) async {
    _currentUploadId = recording.id;
    _uploadProgress = 0.0;
    notifyListeners();

    try {
      // Update status to uploading
      final uploadingRecording = recording.copyWith(status: RecordingStatus.uploading);
      await _databaseService.updateRecording(uploadingRecording);
      notifyListeners();

      // Get upload URL from API
      final uploadResponse = await _apiService.getUploadUrl(
        startTime: recording.startTime,
        durationSeconds: recording.durationSeconds,
        latitude: recording.latitude,
        longitude: recording.longitude,
        geminiModel: recording.geminiModel,
        fileSizeBytes: recording.fileSizeBytes,
      );

      _uploadProgress = 0.3;
      notifyListeners();

      // Upload the file
      final file = File(recording.localPath);
      if (!await file.exists()) {
        throw Exception('Recording file not found: ${recording.localPath}');
      }

      await _apiService.uploadAudioFile(uploadResponse.uploadUrl, file);

      _uploadProgress = 0.8;
      notifyListeners();

      // Mark upload complete (triggers transcription)
      await _apiService.completeUpload(uploadResponse.id);

      _uploadProgress = 1.0;
      notifyListeners();

      // Update local record with SERVER ID (critical for status polling to work!)
      final uploadedRecording = recording.copyWith(
        id: uploadResponse.id,  // Use server-generated ID
        status: RecordingStatus.transcribing,
        audioPath: uploadResponse.audioPath,
      );
      // Replace old local ID with new server ID
      await _databaseService.replaceRecordingId(recording.id, uploadedRecording);
      await _databaseService.removeFromUploadQueue(recording.id);

      // Keep last 3 local files as backup, delete older ones
      await _cleanupOldLocalFiles();
      debugPrint('Upload completed: ${recording.id}');

    } catch (e) {
      debugPrint('Upload failed for ${recording.id}: $e');

      // Update status to failed
      final failedRecording = recording.copyWith(
        status: RecordingStatus.failed,
        error: e.toString(),
      );
      await _databaseService.updateRecording(failedRecording);
      await _databaseService.incrementUploadAttempts(recording.id);
    }
  }

  /// Clean up old local files, keeping only the last 3 as backup
  Future<void> _cleanupOldLocalFiles() async {
    try {
      final allRecordings = await _databaseService.getAllRecordings();

      // Filter recordings that have been successfully uploaded and have local files
      final uploadedWithLocalFiles = allRecordings
          .where((r) =>
              (r.status == RecordingStatus.transcribing ||
                  r.status == RecordingStatus.transcribed) &&
              r.localPath.isNotEmpty)
          .toList();

      // Sort by creation time, newest first
      uploadedWithLocalFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Keep the first 3, delete the rest
      if (uploadedWithLocalFiles.length > 3) {
        for (var i = 3; i < uploadedWithLocalFiles.length; i++) {
          final recording = uploadedWithLocalFiles[i];
          final file = File(recording.localPath);

          if (await file.exists()) {
            await file.delete();
            debugPrint('🗑️ Deleted old backup file: ${recording.localPath}');

            // Update database to clear localPath
            final updated = recording.copyWith(localPath: '');
            await _databaseService.updateRecording(updated);
          }
        }
      }

      debugPrint(
          '💾 Local backup retention: Keeping ${uploadedWithLocalFiles.length > 3 ? 3 : uploadedWithLocalFiles.length} most recent files');
    } catch (e) {
      debugPrint('Error cleaning up old local files: $e');
    }
  }

  Future<void> retryFailed(String recordingId) async {
    final recording = await _databaseService.getRecording(recordingId);
    if (recording == null) return;

    final pendingRecording = recording.copyWith(
      status: RecordingStatus.pending,
      error: null,
    );
    await _databaseService.updateRecording(pendingRecording);
    await _databaseService.addToUploadQueue(recordingId);

    if (await hasInternetConnection()) {
      processUploadQueue();
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
