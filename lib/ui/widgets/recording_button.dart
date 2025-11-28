import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/recording_manager.dart';
import '../../services/foreground_service.dart';

class RecordingButton extends StatelessWidget {
  const RecordingButton({super.key});

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<bool> _requestPermissions() async {
    // Request microphone permission first - required before starting foreground service
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      return false;
    }

    // Request notification permission (for foreground service notification)
    await Permission.notification.request();

    return true;
  }

  Future<void> _toggleRecording(BuildContext context) async {
    final manager = context.read<RecordingManager>();

    if (manager.isRecording) {
      // Stop current segment and immediately restart (seamless)
      await manager.stopRecording(autoRestart: true);
      // Keep foreground service running for continuous recording
    } else {
      // Request permissions BEFORE starting foreground service
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to record'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString('default_model') ?? 'flash';

      // Now safe to start foreground service (permission is granted)
      await startForegroundService();
      await manager.startRecording(geminiModel: model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingManager>(
      builder: (context, manager, child) {
        final isRecording = manager.isRecording;
        final duration = manager.currentDuration;

        return Column(
          children: [
            GestureDetector(
              onTap: () => _toggleRecording(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? Colors.red : Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording ? Colors.red : Colors.blue)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: isRecording ? 10 : 5,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRecording ? 'Recording...' : 'Tap to Record',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRecording) ...[
              const SizedBox(height: 8),
              Text(
                _formatCurrentTime(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Auto-stops at :00 and :30',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
