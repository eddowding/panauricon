# Panauricon

**Continuous voice recording app with AI transcription and speaker detection.**

Panauricon records audio in 30-minute clock-aligned segments, automatically uploads to Firebase Storage, and transcribes using Google's Gemini 2.5 Flash with intelligent speaker detection.

## Features

### Core Recording
- **30-minute segments** - Auto-stops at :00 and :30, immediately restarts
- **Seamless continuity** - Zero-gap recording across segments and app crashes
- **Clock time display** - Shows current time, not elapsed duration
- **Auto-resume** - Restarts recording after app restarts or crashes
- **Battery optimized** - 24kbps AAC-LC, 16kHz, minimal notification

### Transcription
- **Gemini 2.5 Flash** - Fast, accurate, cost-effective (~$3/24hrs)
- **Speaker detection** - Groups speech by speaker naturally
- **Clean format** - Speaker paragraphs without cluttered timestamps
- **Auto-retry** - 3 attempts with exponential backoff for network failures

### Smart Features
- **WiFi-only uploads** - Save mobile data (default ON)
- **Search** - Full-text search across all transcripts
- **Calendar view** - Visual timeline of recordings by date
- **Dark mode** - System-aware theme
- **Local backup** - Keeps last 3 audio files as safety net
- **Health checks** - Verifies recording every 5 minutes, auto-recovers

### Robustness
- **Exponential backoff** - Failed uploads retry at 1min → 5min → 15min → 1hr
- **Battery whitelist prompt** - Prevents Android from killing the app
- **File existence checks** - Graceful handling of missing files
- **Foreground service** - Reliable background recording

## Architecture

```
┌─────────────────┐
│   Flutter App   │
│  (Android)      │
└────────┬────────┘
         │
         ├─> AudioService (record)
         ├─> UploadService (WiFi check)
         ├─> RecordingManager (orchestrate)
         └─> DatabaseService (SQLite)
              │
              ▼
     ┌────────────────┐
     │ Firebase Cloud │
     │   Functions    │
     └────────┬───────┘
              │
              ├─> Cloud Storage (audio)
              ├─> Firestore (metadata)
              └─> Gemini 2.5 (transcribe)
```

## Setup

### Prerequisites
- Flutter 3.10+
- Android SDK
- Firebase project
- Google AI API key (Gemini)

### Installation

1. **Clone**
```bash
git clone https://github.com/eddowding/panauricon.git
cd panauricon
```

2. **Flutter dependencies**
```bash
flutter pub get
```

3. **Firebase setup**
```bash
# Add your google-services.json to android/app/
# Update lib/config.dart with your Firebase project ID and bucket
```

4. **Deploy Cloud Functions**
```bash
cd ../functions
npm install
firebase deploy --only functions
```

5. **Run**
```bash
flutter run
```

## Configuration

**Recording settings** (`lib/config.dart`):
- Segment duration: 30 minutes
- Bitrate: 24 kbps (speech-optimized)
- Sample rate: 16 kHz
- Format: AAC-LC (M4A)

**Costs** (Gemini 2.5 Flash):
- ~$2.50-$3.50 per 24 hours
- ~$76-$107 per month (continuous)
- WiFi-only uploads reduce mobile data costs

## Features Detail

### Auto-Restart Scenarios
1. Clock boundaries (:00, :30) - seamless segment transition
2. Manual stop button - saves segment, immediately restarts
3. App crashes - detects on startup and resumes
4. Phone calls - pauses during call, resumes after

### Transcription Format
```
**Ed:** This is much cleaner without timestamps everywhere.
Speech flows naturally in paragraphs grouped by speaker.

**Sarah:** I agree. The old format was too verbose with
timestamps on every line.

**Ed:** Exactly. Now it's actually readable.
```

### Retry Logic
- Transient network failures: 3 attempts (5s, 15s, 30s delays)
- Persistent failures: Exponential backoff on upload queue
- Manual retry available for any failed transcription

## Project Structure

```
lib/
├── services/        # Core business logic
│   ├── audio_service.dart
│   ├── upload_service.dart
│   ├── recording_manager.dart
│   └── api_service.dart
├── ui/
│   ├── screens/     # Main screens
│   └── widgets/     # Reusable components
├── models/          # Data models
└── config.dart      # App configuration

android/
└── app/src/main/
    ├── kotlin/      # Native Android code
    └── res/         # Resources, icons, widgets
```

## Tech Stack

- **Frontend:** Flutter 3.10, Material 3
- **Backend:** Firebase Cloud Functions (Node.js)
- **Database:** Cloud Firestore + SQLite (local)
- **Storage:** Firebase Cloud Storage (EU)
- **AI:** Google Gemini 2.5 Flash
- **Location:** OpenStreetMap Nominatim (reverse geocoding)

## Contributing

This is a personal project but open to contributions. Please open an issue before major changes.

## License

MIT License - see LICENSE file

## Acknowledgments

Built with Claude Code (Anthropic) during an intensive development session.
