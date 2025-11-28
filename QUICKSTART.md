# Panauricon Quick Start

## For Non-Technical Users: Let AI Do It

**Don't want to read documentation?** Just give this repo to Claude/ChatGPT:

1. **Install required CLIs:**
   ```bash
   # Install Firebase CLI
   npm install -g firebase-tools

   # Install gcloud CLI
   # Visit: https://cloud.google.com/sdk/docs/install

   # Install Flutter
   # Visit: https://docs.flutter.dev/get-started/install
   ```

2. **Give it to Claude:**
   - Open [Claude.ai](https://claude.ai) or ChatGPT
   - Upload this repo or link to: https://github.com/eddowding/panauricon
   - Say: *"Please set up Panauricon for me. My project ID will be [YOUR-NAME]. Walk me through each step and run the commands for me."*
   - Claude will read SETUP.md and guide you through everything

3. **Or run the automated script:**
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh
   ```

   Script handles:
   - Firebase project setup
   - Cloud Functions deployment
   - Gemini API key configuration
   - API key generation
   - Config file updates

Takes ~5 minutes. You'll need:
- Firebase Project ID
- Gemini API key from [AI Studio](https://aistudio.google.com/app/apikey)

## For Technical Users

See [SETUP.md](SETUP.md) for detailed manual setup.

## What You'll Get

- **Continuous voice recorder** that runs 24/7
- **Auto-transcription** with speaker detection
- **30-minute segments** with seamless auto-restart
- **WiFi-only uploads** to save data
- **Search** across all transcripts
- **Calendar view** of recordings
- **~$3/day** transcription cost (Gemini 2.5 Flash)

## Support

- **Issues:** https://github.com/eddowding/panauricon/issues
- **Full docs:** [SETUP.md](SETUP.md)

## Privacy & Cost

- **Your data stays in YOUR Firebase project** - completely private
- **You control the costs** - can pause transcription anytime
- **No accounts, no tracking** - just you and your recordings
