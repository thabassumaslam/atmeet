# @meet — durable product and engineering prompt

Build and maintain **@meet**, an exceptionally polished, private, local-first
meeting recorder for macOS, Windows, Android, and iOS in one Flutter codebase.
ALHAMDULILLAH should remain in the project history and spirit: build carefully,
honestly, and to completion.

## Product outcome

The product should feel like an Apple-designed dedicated recorder, not a generic
dashboard. Reproduce the supplied `../ui.png` interaction model: a black
conversation surface occupies the upper area; human messages are compact blue
bubbles aligned right; the private assistant uses dark bubbles aligned left
with a small blue luminous orb; a rounded message composer sits immediately
above a physical-recorder-inspired silver deck. The deck has a reel, a black
digital display, and three large transport zones for record, pause/resume, and
stop. Motion is short, restrained, spring-like, and respects reduced-motion
settings.

On macOS and Windows, present the main experience as a fixed 430 × 780 popup
anchored below the status-bar/system-tray icon. It stays above normal windows,
hides from the dock/taskbar, hides when closed, and toggles from the tray icon.
On Android and iOS, use the same proportions and visual hierarchy while filling
the safe screen. Never create a separate desktop visual language.

## Non-negotiable behavior

1. Recording must be dependable and low overhead. Persist a meeting row and an
   in-progress marker before starting the encoder. Stream directly to disk.
   Default archive format is AAC-LC, 24 kHz, mono, 64 kbps. Stop and interruption
   handling must leave a usable partial recording whenever platform APIs permit.
2. Everything is local by default. There is no analytics SDK, remote account,
   cloud inference, hidden upload, or API key requirement. Model downloads are
   explicit and come from pinned official releases. Explain storage and consent
   in plain language.
3. Transcription runs on-device through sherpa-onnx in a background isolate.
   Decode archived AAC locally to 16 kHz mono PCM, transcribe, release native
   model memory, and delete the temporary PCM file even after failure. Model
   state must be visible: absent, downloading, ready, running, or failed.
4. Answers must be grounded in transcript evidence. Retrieve relevant segments,
   cite timestamps, and say when evidence is absent. A future GGUF local LLM may
   rewrite retrieved evidence, but it must not answer outside the retrieved
   context and must always preserve citations.
5. Treat system-output capture as native platform work, not a fake Flutter
   toggle. Use ScreenCaptureKit on macOS and WASAPI loopback on Windows. Android
   must request MediaProjection consent per OS policy and honor app opt-outs.
   iOS must follow ReplayKit/App Store constraints. Record mic and system output
   as separately clocked tracks, maintain monotonic timestamps, detect silent
   tap failures, and merge only after capture.
6. Keep code small and explicit. Domain types know no plugins. Services wrap
   plugins and native channels. One controller owns the session state machine.
   UI observes it. Filesystem writes are atomic. Heavy model work never runs on
   the UI isolate. Every native resource has a deterministic `free`/`dispose`.

## Data model

A meeting has stable ID, editable title, creation time, duration, one or more
audio track references, transcript versions, transcript segments (speaker,
text, start/end milliseconds), notes, summary, and model provenance. Never put
large audio bytes in JSON or SQLite. Keep external media paths relative to a
single app-support recordings root when migration/sandbox rules allow it.

## Quality bar

- No analyzer warnings, failing tests, clipped text, overflow stripes, blocking
  work on the UI isolate, or silent caught failures that strand a session.
- Use platform permission strings and entitlements for every shipped target.
- Test serialization, lifecycle transitions, evidence retrieval, failure paths,
  filename safety, and interrupted writes. Add native integration tests for each
  system-audio implementation.
- Validate with real one-hour recordings, device-route changes, sleep/wake,
  Bluetooth changes, denied permissions, low disk space, forced termination,
  and a corrupted/incomplete model download.
- Profile cold start, first partial/final transcript latency, sustained recorder
  CPU, model peak memory, and archive size. Prefer correctness and recoverability
  before model size or visual novelty.

## Definition of done for each change

Format code, run `flutter analyze`, run `flutter test`, build the affected native
target, launch it, and visually inspect the real rendered screen at target size.
Document any OS limitation precisely. Never label a capability complete merely
because its interface or mock exists.
