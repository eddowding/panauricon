import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/recording_manager.dart';
import '../../services/upload_service.dart';
import '../../services/api_service.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<RecordingManager, UploadService, ApiService>(
      builder: (context, manager, uploadService, apiService, child) {
        final isUploading = uploadService.isProcessing;
        final uploadProgress = uploadService.uploadProgress;
        final hasApiKey = apiService.apiKey != null && apiService.apiKey!.isNotEmpty;

        // Count pending uploads
        final pendingCount = manager.recordings
            .where((r) => r.status.name == 'pending' || r.status.name == 'failed')
            .length;

        if (!hasApiKey) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'API key not configured. Go to Settings to add your key.',
                    style: TextStyle(color: Colors.orange[900], fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        if (isUploading) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: uploadProgress > 0 ? uploadProgress : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Uploading recording... ${(uploadProgress * 100).toInt()}%',
                    style: TextStyle(color: Colors.blue[900], fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        if (pendingCount > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[200],
            child: Row(
              children: [
                Icon(Icons.cloud_queue, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pendingCount recording${pendingCount == 1 ? '' : 's'} waiting to upload',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
