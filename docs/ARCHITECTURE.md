# Architecture

## Runtime flow

`MeetingController` is the sole owner of the recording state machine:

```text
idle → recording ⇄ paused → transcribing → idle
```

Before capture, it creates the session directory, `.recording` marker, meeting
model, and catalog entry. This preserves discoverability if the process dies.
The recorder streams AAC to the final session path. Stop removes the marker,
commits duration/path, then optionally enters offline transcription.

`SherpaOfflineTranscriber` owns model presence, explicit download, extraction,
AAC decoding, native inference, and cleanup. FFmpeg produces a temporary mono
16 kHz WAV next to the archive. Sherpa objects live in an isolate and are freed
in `finally`; the WAV is also removed in `finally`.

`LocalAnswerService` is the safe baseline intelligence layer. It scores transcript
segments by query-term overlap and returns the best evidence with timestamps.
It cannot hallucinate because it emits only stored transcript text or a clear
no-evidence response. A local generative model can later sit *after* retrieval.

## Storage

```text
Application Support/atmeet/
├── meetings.json
├── models/sherpa-onnx-whisper-tiny.en/...
└── recordings/<date-session-id>/
    └── meeting.m4a
```

Catalog writes use `meetings.json.tmp` followed by rename. Audio is external so
catalog operations stay fast and future transcript versions do not duplicate
media.

## Source-project learnings

Biscotti contributed the validated voice archive preset (AAC-LC, mono, 24 kHz,
64 kbps), create-before-capture persistence, marker-based orphan recovery idea,
and strict separation between capture, catalog, transcription, and intelligence.
Voxt contributed model lifecycle discipline, local-ASR readiness boundaries,
background execution, and evidence-oriented meeting flows. This Flutter code is
a clean portable implementation rather than a line-for-line Swift port.

## Next native modules

System audio belongs behind a method-channel implementation with a shared Dart
contract. Each platform should return independently timestamped track files and
health events. macOS uses ScreenCaptureKit; Windows uses shared-mode WASAPI
loopback; Android uses MediaProjection/AudioPlaybackCapture with visible user
consent; iOS uses only the capture surface permitted by ReplayKit and App Store
policy. Tracks should be merged after stop so a failure in one source never
destroys the other.
