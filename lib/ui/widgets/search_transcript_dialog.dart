import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class SearchTranscriptDialog extends StatelessWidget {
  final ApiRecording recording;

  const SearchTranscriptDialog({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(recording.createdAt),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: recording.transcriptText ?? ''),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transcript copied to clipboard')),
              );
            },
            tooltip: 'Copy transcript',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: SingleChildScrollView(
          child: SelectableText(
            recording.transcriptText ?? 'No transcript available',
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
