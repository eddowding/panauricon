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
  static const int audioBitrate = 24000; // 24 kbps for speech
  static const int sampleRate = 16000; // 16 kHz optimal for speech

  // Storage Configuration
  static const int maxLocalStorageMB = 500; // ~15 recordings buffer

  // Default Gemini model
  static const String defaultGeminiModel = 'flash'; // 'flash' or 'pro'
}
