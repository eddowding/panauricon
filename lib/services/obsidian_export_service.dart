import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/recording.dart';

class ObsidianExportService {
  static const String _exportFolderName = 'Panauricon';

  /// Get the export directory path
  Future<Directory> getExportDirectory() async {
    // Use external storage on Android for easy access
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
      // Navigate up to find a more accessible path
      if (baseDir != null) {
        // Go to /storage/emulated/0/Documents/Panauricon
        final parts = baseDir.path.split('/');
        final androidIndex = parts.indexOf('Android');
        if (androidIndex > 0) {
          final publicPath = parts.sublist(0, androidIndex).join('/');
          baseDir = Directory('$publicPath/Documents/$_exportFolderName');
        }
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
      baseDir = Directory('${baseDir.path}/$_exportFolderName');
    }

    baseDir ??= Directory('${(await getApplicationDocumentsDirectory()).path}/$_exportFolderName');

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return baseDir;
  }

  /// Export a single recording as markdown
  Future<String> exportRecording(Recording recording) async {
    final exportDir = await getExportDirectory();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH-mm-ss');
    final displayTimeFormat = DateFormat('HH:mm:ss');

    final date = dateFormat.format(recording.startTime);
    final time = timeFormat.format(recording.startTime);
    final filename = '${date}_$time.md';
    final filepath = '${exportDir.path}/$filename';

    final duration = Duration(seconds: recording.durationSeconds);
    final durationStr = _formatDuration(duration);

    // Build markdown content with Obsidian-friendly frontmatter
    final buffer = StringBuffer();

    // YAML frontmatter for Obsidian
    buffer.writeln('---');
    buffer.writeln('type: voice-recording');
    buffer.writeln('date: $date');
    buffer.writeln('time: ${displayTimeFormat.format(recording.startTime)}');
    buffer.writeln('duration: $durationStr');
    buffer.writeln('duration_seconds: ${recording.durationSeconds}');
    if (recording.latitude != null && recording.longitude != null) {
      buffer.writeln('location: [${recording.latitude}, ${recording.longitude}]');
    }
    buffer.writeln('status: ${recording.status.name}');
    buffer.writeln('tags:');
    buffer.writeln('  - panauricon');
    buffer.writeln('  - voice-recording');
    buffer.writeln('---');
    buffer.writeln();

    // Title
    buffer.writeln('# Voice Recording - $date');
    buffer.writeln();

    // Metadata
    buffer.writeln('**Recorded:** ${recording.startTime.toIso8601String()}');
    buffer.writeln('**Duration:** $durationStr');
    if (recording.latitude != null && recording.longitude != null) {
      buffer.writeln('**Location:** ${recording.latitude?.toStringAsFixed(4)}, ${recording.longitude?.toStringAsFixed(4)}');
    }
    buffer.writeln('**ID:** ${recording.id}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    // Transcript
    buffer.writeln('## Transcript');
    buffer.writeln();
    if (recording.transcriptText != null && recording.transcriptText!.isNotEmpty) {
      buffer.writeln(recording.transcriptText);
    } else {
      buffer.writeln('*Transcription pending...*');
    }
    buffer.writeln();

    // Write file
    final file = File(filepath);
    await file.writeAsString(buffer.toString());

    debugPrint('Exported recording to: $filepath');
    return filepath;
  }

  /// Export all recordings with transcripts
  Future<List<String>> exportAllRecordings(List<Recording> recordings) async {
    final exported = <String>[];

    for (final recording in recordings) {
      if (recording.status == RecordingStatus.transcribed ||
          recording.transcriptText != null) {
        try {
          final path = await exportRecording(recording);
          exported.add(path);
        } catch (e) {
          debugPrint('Failed to export ${recording.id}: $e');
        }
      }
    }

    return exported;
  }

  /// Export recordings from a specific date
  Future<List<String>> exportRecordingsForDate(
    List<Recording> recordings,
    DateTime date,
  ) async {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    final filtered = recordings.where((r) =>
        r.startTime.isAfter(dateStart) &&
        r.startTime.isBefore(dateEnd) &&
        (r.status == RecordingStatus.transcribed || r.transcriptText != null));

    final exported = <String>[];
    for (final recording in filtered) {
      try {
        final path = await exportRecording(recording);
        exported.add(path);
      } catch (e) {
        debugPrint('Failed to export ${recording.id}: $e');
      }
    }

    return exported;
  }

  /// Create a daily summary note (for Obsidian daily notes integration)
  Future<String> createDailySummary(
    List<Recording> recordings,
    DateTime date,
  ) async {
    final exportDir = await getExportDirectory();
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);
    final filename = '$dateStr-summary.md';
    final filepath = '${exportDir.path}/$filename';

    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = dateStart.add(const Duration(days: 1));

    final dayRecordings = recordings.where((r) =>
        r.startTime.isAfter(dateStart) && r.startTime.isBefore(dateEnd)).toList();

    final buffer = StringBuffer();

    // YAML frontmatter
    buffer.writeln('---');
    buffer.writeln('type: daily-summary');
    buffer.writeln('date: $dateStr');
    buffer.writeln('recording_count: ${dayRecordings.length}');
    buffer.writeln('tags:');
    buffer.writeln('  - panauricon');
    buffer.writeln('  - daily-summary');
    buffer.writeln('---');
    buffer.writeln();

    buffer.writeln('# Daily Voice Summary - $dateStr');
    buffer.writeln();
    buffer.writeln('## Recordings');
    buffer.writeln();

    if (dayRecordings.isEmpty) {
      buffer.writeln('No recordings for this day.');
    } else {
      final timeFormat = DateFormat('HH:mm');
      for (final recording in dayRecordings) {
        final time = timeFormat.format(recording.startTime);
        final duration = _formatDuration(Duration(seconds: recording.durationSeconds));
        final linkName = '${dateStr}_${timeFormat.format(recording.startTime).replaceAll(':', '-')}';

        buffer.writeln('- **$time** ($duration) - [[$linkName]]');

        // Include brief excerpt if transcript available
        if (recording.transcriptText != null && recording.transcriptText!.length > 50) {
          final excerpt = recording.transcriptText!.substring(0, 100).replaceAll('\n', ' ');
          buffer.writeln('  > $excerpt...');
        }
        buffer.writeln();
      }
    }

    final file = File(filepath);
    await file.writeAsString(buffer.toString());

    return filepath;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
