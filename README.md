# @meet

ALHAMDULILLAH — a private, local-first meeting recorder for macOS, Windows,
Android, and iOS, built with Flutter.

The interface deliberately keeps the same focused recorder dimensions on a
laptop as on a phone. On desktop it behaves as a 430 × 780 status-bar/tray
panel; on mobile it fills the screen. The visual language follows the supplied
TP-7-inspired reference: conversation above, tactile recorder controls below.

## What works

- Low-storage voice recording: AAC-LC, mono, 24 kHz, 64 kbps (about 28.8 MB/hour).
- Start, pause, resume, crash-marker-backed stop/save, and local playback.
- Private JSON catalog and recordings in the platform application-support folder.
- Offline Whisper transcription through `sherpa_onnx`; the model downloads only
  when the user asks and inference runs in a background isolate.
- Local AAC-to-16 kHz PCM preparation via the audio-only LGPL FFmpeg package.
- Transcript-grounded questions with timestamp citations and an explicit
  no-evidence response instead of invented answers.
- macOS and Windows tray integration, fixed popup sizing, always-on-top behavior,
  click-to-show/hide, and close-to-hide.
- Microphone permission declarations for Android, iOS, and macOS; background
  audio mode on iOS.

## Run

Flutter 3.47.2 or newer is recommended.

```bash
flutter pub get
flutter test
flutter run -d macos
# flutter run -d windows
# flutter run -d android
# flutter run -d ios
```

The first local model installation downloads `sherpa-onnx-whisper-tiny.en`
(roughly 113 MB) from the official sherpa-onnx release. No model, audio,
transcript, or question is sent to a service.

## Architecture

```text
lib/
├── app/          theme and app composition
├── controllers/  recording + transcription state machine
├── domain/       stable meeting/transcript/chat models
├── services/     audio, storage, offline ASR, local grounded answers, tray
└── ui/           reference-matched recorder/chat surface
```

This adopts the strongest patterns found in the supplied Biscotti and Voxt
projects—single-owner recording lifecycle, early persistence, crash markers,
isolated model execution, model readiness checks, and evidence-first answers—
while rewriting them cleanly for portable Dart/Flutter.

## Platform capture boundary

The shipping recorder captures the selected microphone on every requested
platform. Capturing *other applications’* output is intentionally a separate
native capability because the operating systems do not expose one portable
API: ScreenCaptureKit on macOS, WASAPI loopback on Windows, consent-scoped
AudioPlaybackCapture on Android, and ReplayKit restrictions on iOS. The current
Flutter service boundary is designed so those native implementations can be
added without touching the UI, catalog, or ASR pipeline. The app never claims
to capture system audio when the OS has not granted and delivered it.

## Privacy and storage

Recordings and `meetings.json` live under the OS application-support directory.
The catalog is written through a temporary file and renamed so an interrupted
write cannot leave half a JSON document. A `.recording` marker is created before
capture and removed after a successful stop. Enable FileVault, BitLocker, or
device encryption for at-rest protection of raw media.

See [PRODUCT_PROMPT.md](PRODUCT_PROMPT.md) for the durable implementation brief
and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for deeper engineering notes.
