#!/bin/bash
set -e

echo "🎙️ Panauricon Auto-Setup Script"
echo "================================"
echo ""

# Check prerequisites
command -v firebase >/dev/null 2>&1 || { echo "❌ Firebase CLI not installed. Run: npm install -g firebase-tools"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "❌ Flutter not installed. Visit: https://docs.flutter.dev/get-started/install"; exit 1; }
command -v gcloud >/dev/null 2>&1 || { echo "❌ gcloud CLI not installed. Visit: https://cloud.google.com/sdk/docs/install"; exit 1; }

echo "✅ All prerequisites found"
echo ""

# Get user input
read -p "Enter your Firebase Project ID (e.g., panauricon-yourname): " PROJECT_ID
read -p "Enter your Gemini API key (from https://aistudio.google.com/app/apikey): " GEMINI_KEY

echo ""
echo "📋 Configuration:"
echo "  Project: $PROJECT_ID"
echo "  Region: europe-west1"
echo ""

# Update config.dart
echo "📝 Updating config.dart..."
sed -i.bak "s/limitless-voice-recorder/$PROJECT_ID/g" lib/config.dart
sed -i.bak "s|https://europe-west1-limitless-voice-recorder.cloudfunctions.net/api|https://europe-west1-$PROJECT_ID.cloudfunctions.net/api|" lib/config.dart

# Download google-services.json
echo "📥 Downloading google-services.json..."
firebase apps:sdkconfig android --project=$PROJECT_ID -o android/app/google-services.json

# Install dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Deploy Cloud Functions
echo "🚀 Deploying Cloud Functions..."
cd functions
npm install

# Set Gemini API key as secret
echo "$GEMINI_KEY" | firebase functions:secrets:set GEMINI_API_KEY --project=$PROJECT_ID --force

# Deploy functions
firebase deploy --only functions --project=$PROJECT_ID

cd ..

# Generate API key
API_KEY="vr_$(openssl rand -hex 16)"
echo ""
echo "🔑 Generated API key: $API_KEY"

# Add API key to Firestore
echo "💾 Registering API key in Firestore..."
curl -X POST "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/api_keys?documentId=$API_KEY" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d "{\"fields\":{\"active\":{\"booleanValue\":true},\"createdAt\":{\"stringValue\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"},\"name\":{\"stringValue\":\"Setup Script Key\"}}}" \
  > /dev/null 2>&1

echo ""
echo "✅ Setup complete!"
echo ""
echo "📱 Next steps:"
echo "  1. Build app: flutter build apk"
echo "  2. Install: flutter install"
echo "  3. Enter API key in app: $API_KEY"
echo ""
echo "🎉 Your Panauricon instance is ready!"
echo ""
echo "💰 Estimated costs: ~\$3/day for 24hr continuous recording"
