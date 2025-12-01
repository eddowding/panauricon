class AppConfig {
  // Firebase Configuration
  static const String projectId = 'limitless-voice-recorder';
  static const String storageBucket = 'limitless-voice-recorder-audio-eu';

  // API Configuration
  static const String apiBaseUrl = 'https://europe-west1-limitless-voice-recorder.cloudfunctions.net/api';

  // Recording Configuration
  static const int segmentDurationMinutes = 30; // 30-minute segments aligned to clock
  static const int maxRecordingDurationHours = 12; // Max single recording if not stopped
  static const int maxRecordingDurationSeconds = maxRecordingDurationHours * 3600;
  static const int audioBitrate = 64000; // 64 kbps for better quality
  static const int sampleRate = 44100; // 44.1 kHz CD quality

  // Storage Configuration
  static const int maxLocalStorageMB = 1024; // ~30 recordings buffer (1GB)

  // Default Gemini model
  static const String defaultGeminiModel = 'flash'; // 'flash' or 'pro'
}
