import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationService {
  static const _hasAskedKey = 'battery_optimization_asked';

  /// Check and request battery optimization exemption
  static Future<void> checkAndRequestBatteryOptimization(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool(_hasAskedKey) ?? false;

    // Only ask once
    if (hasAsked) return;

    // Check if already exempted
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      await prefs.setBool(_hasAskedKey, true);
      return;
    }

    // Show explanation dialog
    if (context.mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Background Recording'),
          content: const Text(
            'Panauricon needs to run in the background to record continuously. '
            'Please disable battery optimization to prevent Android from stopping the app.\n\n'
            'This is essential for reliable 24/7 recording.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );

      if (shouldRequest == true) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      await prefs.setBool(_hasAskedKey, true);
    }
  }

  /// Check if battery optimization is disabled
  static Future<bool> isOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.status;
    return status.isGranted;
  }
}
