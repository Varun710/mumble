# Flow (Mumble)

A local-first macOS dictation and transcription app. Everything runs on-device with
[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) — no account, no cloud, no audio ever leaves your Mac.

Flow is two things in one:

- A **windowed transcription manager**: record, get a cleaned transcript with timestamped
  segments, play it back with a synced playhead, search your library, and keep notes.
- A **global push-to-talk dictation tool**: hold a hotkey anywhere, speak, release, and the
  cleaned text is pasted straight into whatever app you're using.

![Flow](docs/screenshot.png)

## Features

- On-device speech-to-text via WhisperKit (downloads the model on first use).
- Window recording with a record orb, live waveform, and automatic transcription.
- Global push-to-talk dictation with a floating overlay capsule (default hotkey: `⌃⌥Space`).
- Deterministic text cleanup: filler-word removal (`um`, `uh`, …), repeated-word collapsing,
  spacing/punctuation normalization, and a custom dictionary.
- Transcript player: waveform scrubbing, tap-a-segment to seek, current-segment highlight,
  variable playback speed, per-recording notes.
- Local library stored with SwiftData; audio + database + models live under
  `~/Library/Application Support/com.mumble.app/`.
- Menu-bar presence with a runtime Dock-icon toggle (background agent when no window is open).
- AI Commands panel (Summarize / Action Items / …) is present but disabled — reserved for a
  future local-LLM phase.

## Requirements

- macOS 14 or later (built and tested on macOS 26).
- Xcode 16 or later (developed with Xcode 26.6).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:
  `brew install xcodegen`.

## Build & run

The Xcode project is generated from [`project.yml`](project.yml) and is not committed.

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2a. Open in Xcode and run (recommended)
open Mumble.xcodeproj
#    then press Cmd+R

# 2b. …or build from the command line
xcodebuild -project Mumble.xcodeproj -scheme Mumble \
  -configuration Debug -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" build
```

If `xcodebuild` reports it can't find Xcode, point it at your full Xcode install:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
# or prefix one-off commands with:
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

On first launch, Flow downloads the selected WhisperKit model (default: **Base**, ~145 MB).
Pick a different model in **Settings → Models** — `Large v3 Turbo` is recommended for the best
accuracy/speed on Apple Silicon.

## Permissions

Flow asks for three macOS permissions (manage them in **Settings → Permissions**):

| Permission | Why | Where |
| --- | --- | --- |
| **Microphone** | Record audio to transcribe | prompted in-app |
| **Accessibility** | Paste dictated text into other apps (synthesized `⌘V`) | System Settings → Privacy & Security → Accessibility |
| **Input Monitoring** | Global push-to-talk hotkey | System Settings → Privacy & Security → Input Monitoring |

> Accessibility/Input-Monitoring grants are tied to the signed binary at a specific path.
> If you move the app or rebuild with a different signature, re-grant the permission.

## Why it's not sandboxed

Pasting into arbitrary apps uses `CGEvent.post` to synthesize `⌘V`, which is **blocked by the
App Sandbox with no entitlement workaround**. Flow therefore ships **non-sandboxed**
(Developer ID + Hardened Runtime + notarization for distribution). This is standard for
dictation utilities and rules out Mac App Store distribution.

## Running an unsigned release

If you distribute an unsigned `.zip`/`.dmg` (no Apple Developer account), Gatekeeper will warn
on first open. Users can bypass it with:

- **Right-click the app → Open → Open**, or
- `xattr -dr com.apple.quarantine /Applications/Flow.app`

## Project structure

```
Mumble/
├─ App/            App entry, delegate, environment, Dock activation policy
├─ Permissions/    Microphone / Accessibility / Input Monitoring
├─ Audio/          AudioPipeline (actor), RecorderViewModel, WaveformAnalyzer
├─ Transcription/  TranscriptionEngine protocol, WhisperKitEngine, ModelManager, service
├─ Polish/         TextCleaner pipeline (fillers, repeats, punctuation, dictionary)
├─ Output/         Clipboard + paste (CGEvent ⌘V)
├─ Dictation/      Push-to-talk controller + floating NSPanel overlay
├─ Storage/        SwiftData models, persistence, paths, settings
└─ UI/             Sidebar, Home, Recordings (+ transcript player), Notes, Settings, components
```

## Roadmap

- Local-LLM AI Commands (Summarize, Action Items, Decisions, Notes, custom prompts).
- Additional engines behind `TranscriptionEngine` (Parakeet, Apple Speech).
- Streaming/partial transcripts during dictation.
- Signed + notarized releases and Sparkle auto-update.

## License

Source-available for personal use. WhisperKit and KeyboardShortcuts retain their own licenses.
