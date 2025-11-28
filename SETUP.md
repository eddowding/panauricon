# Panauricon Setup Guide

Complete step-by-step guide to deploy your own Panauricon instance.

## Prerequisites

- **Flutter SDK** 3.10 or higher ([install](https://docs.flutter.dev/get-started/install))
- **Android Studio** with Android SDK
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Google Cloud account** with billing enabled
- **Node.js** 20+ for Cloud Functions

## Step 1: Clone the Repository

```bash
git clone https://github.com/eddowding/panauricon.git
cd panauricon
```

## Step 2: Create Firebase Project

1. **Go to** [Firebase Console](https://console.firebase.google.com/)
2. **Create new project** → Choose a name (e.g., `panauricon-yourname`)
3. **Enable Google Analytics** (optional)
4. **Wait** for project to be created

## Step 3: Set Up Firebase Services

### 3.1 Enable Firestore

1. In Firebase Console → **Firestore Database**
2. Click **Create database**
3. Choose **Production mode**
4. Select location: **eur3** (Europe) or your preferred region
5. Click **Enable**

### 3.2 Set Up Security Rules

Go to Firestore → **Rules** tab, paste:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Public read for API keys (validated by Cloud Function)
    match /api_keys/{key} {
      allow read: if true;
      allow write: if false; // Only create manually
    }

    // Recordings - read/write via API key validation in Cloud Function
    match /recordings/{recordingId} {
      allow read, write: if true; // Cloud Function validates
    }
  }
}
```

### 3.3 Enable Cloud Storage

1. Firebase Console → **Storage**
2. Click **Get started**
3. Choose **Production mode**
4. Select same location as Firestore (eur3)
5. Click **Done**

### 3.4 Set Storage Rules

Storage → **Rules** tab:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /audio/{filename} {
      allow read, write: if true; // Cloud Function validates
    }
  }
}
```

## Step 4: Configure Firebase in App

### 4.1 Add Android App

1. Firebase Console → **Project settings** (gear icon)
2. Under "Your apps" → **Add app** → Android
3. **Package name:** `com.limitless.voicerecorder` (or change in `android/app/build.gradle.kts`)
4. **App nickname:** Panauricon
5. Click **Register app**
6. **Download `google-services.json`**
7. Place it in: `android/app/google-services.json`

### 4.2 Update Config

Edit `lib/config.dart`:

```dart
class AppConfig {
  static const String projectId = 'YOUR-PROJECT-ID'; // From Firebase
  static const String storageBucket = 'YOUR-PROJECT-ID.appspot.com';
  static const String apiBaseUrl = 'https://YOUR-REGION-YOUR-PROJECT-ID.cloudfunctions.net/api';
  // ... rest stays same
}
```

## Step 5: Get Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **Get API key** → **Create API key**
3. Copy the key (starts with `AIza...`)
4. **Save it** - you'll need it in Step 6

## Step 6: Deploy Cloud Functions

```bash
cd functions
npm install

# Set Gemini API key as secret
firebase functions:secrets:set GEMINI_API_KEY --project YOUR-PROJECT-ID
# Paste your Gemini API key when prompted

# Deploy
firebase deploy --only functions --project YOUR-PROJECT-ID
```

Wait ~2 minutes for deployment. Note the Function URL that's printed.

## Step 7: Create Your API Key

API keys are stored in Firestore. Create one manually:

**Via Firebase Console:**
1. Firestore → **api_keys** collection
2. **Add document**
3. Document ID: `vr_` + random string (e.g., `vr_abc123xyz789`)
4. Fields:
   - `active` (boolean): `true`
   - `createdAt` (string): Current timestamp
   - `name` (string): "My Key"

**Or via gcloud:**
```bash
KEY_ID="vr_$(openssl rand -hex 16)"
echo "Your API key: $KEY_ID"

curl -X POST "https://firestore.googleapis.com/v1/projects/YOUR-PROJECT-ID/databases/(default)/documents/api_keys?documentId=$KEY_ID" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{\"fields\":{\"active\":{\"booleanValue\":true},\"createdAt\":{\"stringValue\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},\"name\":{\"stringValue\":\"Production Key\"}}}"
```

Save the API key - you'll need it in the app!

## Step 8: Build and Install

```bash
cd .. # Back to project root
flutter pub get
flutter build apk --release

# Install on connected device
flutter install
```

## Step 9: Configure App

1. Open Panauricon app
2. Go to **Settings**
3. Enter your API key (from Step 7)
4. Choose model: **Flash** (cheap) or **Pro** (accurate)
5. Save settings
6. You should see green ✅ if key is valid

## Step 10: Test Recording

1. Tap the **blue microphone button**
2. Grant microphone permission
3. Recording starts - shows current time
4. Wait 30 seconds
5. Check Settings → you should see recordings uploading

## Troubleshooting

**"Invalid API key" error:**
- Verify API key exists in Firestore `api_keys` collection
- Check `active` field is `true`
- Ensure no typos

**Upload fails:**
- Check WiFi is connected (WiFi-only uploads by default)
- Verify Cloud Functions deployed successfully
- Check Firebase Storage rules allow writes

**Transcription fails:**
- Verify Gemini API key is set: `firebase functions:secrets:access GEMINI_API_KEY`
- Check Cloud Functions logs: `firebase functions:log`
- Ensure billing is enabled on Google Cloud

**App crashes:**
- Check `google-services.json` is in `android/app/`
- Verify package name matches Firebase app registration
- Run `flutter doctor` to check setup

## Cost Breakdown

**Firebase (Free tier covers light use):**
- Firestore: Free for <50K reads/day
- Storage: Free for <5GB
- Functions: Free for <2M invocations/month

**Gemini 2.5 Flash:**
- ~$2.50-$3.50 per 24 hours of audio
- ~$76-$107 per month (continuous recording)

**Total for personal use:** ~$80-$110/month if recording 24/7

## Optional: Release Build

To create a properly signed APK for distribution:

1. **Generate signing key:**
```bash
keytool -genkey -v -keystore panauricon-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias panauricon
```

2. **Create `android/key.properties`:**
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=panauricon
storeFile=../panauricon-release.jks
```

3. **Build signed APK:**
```bash
flutter build apk --release
```

4. **Add to .gitignore:**
```
*.jks
key.properties
```

## For Contributors

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup.

## Support

- **Issues:** https://github.com/eddowding/panauricon/issues
- **Discussions:** https://github.com/eddowding/panauricon/discussions

## Security Notes

- **Never commit** `google-services.json` to git
- **Never commit** API keys or secrets
- **Restrict** Firebase Web API key to your Android package name
- **Enable** Firebase App Check for production (optional but recommended)
- **Review** Firestore Security Rules before production deployment

## Next Steps

After successful setup:
1. Configure **WiFi-only uploads** in Settings (default ON)
2. Set up **battery optimization exemption** (app will prompt)
3. Add **home screen widget** for quick access
4. Enable **Dark mode** if preferred
5. Test the **Search** and **Calendar** features

Your Panauricon instance is now running! All recordings will be private to your Firebase project.
