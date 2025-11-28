import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/recording_manager.dart';
import '../../services/upload_service.dart';
import '../../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedModel = 'flash';
  bool _isLoading = true;
  bool _isRestoring = false;
  bool? _apiKeyValid; // null = not tested, true = valid, false = invalid
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiService = context.read<ApiService>();

    setState(() {
      _apiKeyController.text = apiService.apiKey ?? '';
      _selectedModel = prefs.getString('default_model') ?? 'flash';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isValidating = true);

    final apiService = context.read<ApiService>();
    final prefs = await SharedPreferences.getInstance();
    final key = _apiKeyController.text.trim();

    // Validate API key by making a test call
    await apiService.setApiKey(key);

    try {
      await apiService.listRecordings(limit: 1);
      setState(() {
        _apiKeyValid = true;
        _isValidating = false;
      });

      await prefs.setString('default_model', _selectedModel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settings saved - API key is valid'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _apiKeyValid = false;
        _isValidating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Invalid API key: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreFromServer() async {
    setState(() => _isRestoring = true);

    try {
      final apiService = context.read<ApiService>();
      final recordingManager = context.read<RecordingManager>();

      // Fetch all recordings from server
      final serverRecordings = await apiService.listRecordings(limit: 100);

      // Import them into local database
      for (final apiRec in serverRecordings) {
        // Convert ApiRecording to Recording (without local file)
        await recordingManager.importServerRecording(apiRec);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored ${serverRecordings.length} recordings from server')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      setState(() => _isRestoring = false);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Key Section
          const Text(
            'API Configuration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'Enter your API key',
              border: const OutlineInputBorder(),
              suffixIcon: _isValidating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _apiKeyValid == null
                      ? null
                      : Icon(
                          _apiKeyValid! ? Icons.check_circle : Icons.error,
                          color: _apiKeyValid! ? Colors.green : Colors.red,
                        ),
            ),
            obscureText: true,
            onChanged: (_) => setState(() => _apiKeyValid = null), // Reset validation on change
          ),
          const SizedBox(height: 8),
          const Text(
            'Required to upload and transcribe recordings.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),

          const SizedBox(height: 16),

          // Theme selection
          const Text(
            'Appearance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Consumer<ThemeService>(
            builder: (context, themeService, _) => Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light mode'),
                  value: ThemeMode.light,
                  groupValue: themeService.themeMode,
                  onChanged: (value) => themeService.setThemeMode(value!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark mode'),
                  value: ThemeMode.dark,
                  groupValue: themeService.themeMode,
                  onChanged: (value) => themeService.setThemeMode(value!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('System default'),
                  value: ThemeMode.system,
                  groupValue: themeService.themeMode,
                  onChanged: (value) => themeService.setThemeMode(value!),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // WiFi-only upload toggle
          Consumer<UploadService>(
            builder: (context, uploadService, _) => SwitchListTile(
              title: const Text('WiFi-only uploads'),
              subtitle: const Text('Only upload recordings when connected to WiFi'),
              value: uploadService.wifiOnlyUpload,
              onChanged: (value) {
                uploadService.wifiOnlyUpload = value;
              },
            ),
          ),

          const SizedBox(height: 24),

          // Gemini Model Section
          const Text(
            'Transcription Model',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('Gemini Flash'),
            subtitle: const Text('Faster, cheaper (~\$0.075/hr)'),
            value: 'flash',
            groupValue: _selectedModel,
            onChanged: (value) => setState(() => _selectedModel = value!),
          ),
          RadioListTile<String>(
            title: const Text('Gemini Pro'),
            subtitle: const Text('More accurate (~\$0.30/hr)'),
            value: 'pro',
            groupValue: _selectedModel,
            onChanged: (value) => setState(() => _selectedModel = value!),
          ),

          const SizedBox(height: 24),

          // Save Button
          ElevatedButton(
            onPressed: _saveSettings,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Save Settings'),
            ),
          ),

          const SizedBox(height: 24),

          // Data Management Section
          const Text(
            'Data Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isRestoring ? null : _restoreFromServer,
            icon: _isRestoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download),
            label: Text(_isRestoring ? 'Restoring...' : 'Restore from Server'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pull down all your recordings from the server.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),

          const SizedBox(height: 32),

          // Info Section
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Recordings are split into 30-minute segments'),
                  Text('• Auto-stops at :00 and :30, then auto-restarts'),
                  Text('• Uploads when connected to internet'),
                  Text('• Transcriptions include timestamps'),
                  Text('• Location captured at recording start'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
