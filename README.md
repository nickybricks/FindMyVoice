# FindMyVoice

A lightweight macOS app — global hotkey voice-to-text that pastes into any app.

## Requirements

- macOS 14+
- Python 3.10+
- Xcode 15+
- An OpenAI API key **or** use NVIDIA NeMo for free local transcription

## Quick Start

```bash
# 1. Set up the Python backend
make setup

# 2. Add your API key
# Edit ~/.findmyvoice/config.json and set "api_key"

# 3. Build, install to /Applications, and launch
make install
```

## Usage

1. The app lives in your menu bar (mic icon).
2. Press **F5** (default) to start recording.
3. Press **F5** again to stop — audio is transcribed and pasted into the active app.
4. Open **Settings** from the menu bar icon to configure hotkey, API, sounds, etc.

### Local Transcription (NeMo)

In Settings → API, select **NeMo (Local)** as the provider. If the NeMo toolkit isn't installed, the app will prompt you to install it automatically (~2 GB download, one-time). Once installed, transcription runs fully on-device with no API key required.

The Python backend is bundled inside the app and starts automatically — no need to run it separately.

## Project Structure

```
FindMyVoice/
├── backend/                  # Python recording + transcription backend
│   ├── findmyvoice_core.py
│   ├── requirements.txt
│   └── setup.sh
├── FindMyVoiceApp/           # SwiftUI macOS app
│   ├── FindMyVoiceApp.swift
│   ├── SettingsView.swift
│   ├── APIClient.swift
│   └── Models.swift
├── FindMyVoice.xcodeproj/
├── Makefile
└── README.md
```

## Permissions

The app needs:
- **Microphone** — to record your voice
- **Accessibility** — to simulate Cmd+V paste into other apps

macOS will prompt you to grant these on first use.

## Make Targets

| Target | Description |
|--------|-------------|
| `make setup` | Create venv and install Python dependencies |
| `make install` | Build app, bundle backend, install to /Applications, and launch |
| `make run-backend` | Start the Python backend on localhost:7890 (standalone) |
| `make build-app` | Build the SwiftUI app with xcodebuild |
| `make run-all` | Start backend + build and launch the app |
| `make clean` | Clean build artifacts |
