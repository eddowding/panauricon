import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/recording.dart';
import '../../services/recording_manager.dart';
import 'transcript_dialog.dart';

class RecordingList extends StatelessWidget {
  const RecordingList({super.key});

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String _formatFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  IconData _getStatusIcon(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return Icons.fiber_manual_record;
      case RecordingStatus.pending:
        return Icons.schedule;
      case RecordingStatus.uploading:
        return Icons.cloud_upload;
      case RecordingStatus.uploaded:
        return Icons.cloud_done;
      case RecordingStatus.transcribing:
        return Icons.transcribe;
      case RecordingStatus.transcribed:
        return Icons.done_all;
      case RecordingStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _getStatusColor(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return Colors.red;
      case RecordingStatus.pending:
        return Colors.grey;
      case RecordingStatus.uploading:
      case RecordingStatus.transcribing:
        return Colors.orange;
      case RecordingStatus.uploaded:
      case RecordingStatus.transcribed:
        return Colors.green;
      case RecordingStatus.failed:
        return Colors.red[900]!;
    }
  }

  String _getStatusText(RecordingStatus status) {
    switch (status) {
      case RecordingStatus.recording:
        return 'Recording';
      case RecordingStatus.pending:
        return 'Waiting to upload';
      case RecordingStatus.uploading:
        return 'Uploading...';
      case RecordingStatus.uploaded:
        return 'Processing...';
      case RecordingStatus.transcribing:
        return 'Transcribing...';
      case RecordingStatus.transcribed:
        return 'Ready';
      case RecordingStatus.failed:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingManager>(
      builder: (context, manager, child) {
        // Filter out the current recording (shown in button)
        final recordings = manager.recordings
            .where((r) => r.status != RecordingStatus.recording)
            .toList();

        if (recordings.isEmpty) {
          return const Center(
            child: Text(
              'No recordings yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: recordings.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final recording = recordings[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  _getStatusIcon(recording.status),
                  color: _getStatusColor(recording.status),
                  size: 32,
                ),
                title: Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(recording.startTime),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDuration(recording.durationSeconds)} • '
                      '${_formatFileSize(recording.fileSizeBytes)} • '
                      '${_getStatusText(recording.status)}',
                    ),
                    if (recording.transcriptText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          recording.transcriptText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (recording.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          recording.error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    if (recording.latitude != null && recording.longitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${recording.latitude!.toStringAsFixed(4)}, ${recording.longitude!.toStringAsFixed(4)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'view':
                        if (recording.transcriptText != null) {
                          showDialog(
                            context: context,
                            builder: (_) => TranscriptDialog(recording: recording),
                          );
                        }
                        break;
                      case 'retry':
                        await manager.retryRecording(recording.id);
                        break;
                      case 'delete':
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Recording'),
                            content: const Text(
                              'Are you sure you want to delete this recording?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await manager.deleteRecording(recording.id);
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (recording.transcriptText != null)
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('View Transcript'),
                          ],
                        ),
                      ),
                    if (recording.status == RecordingStatus.failed)
                      const PopupMenuItem(
                        value: 'retry',
                        child: Row(
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Retry'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: recording.transcriptText != null
                    ? () {
                        showDialog(
                          context: context,
                          builder: (_) => TranscriptDialog(recording: recording),
                        );
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
