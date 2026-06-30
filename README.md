# Mumble

A local-first macOS dictation and transcription app. Everything runs on-device with
[WhisperKit](https://github.com/argmaxinc/argmax-oss-swift) — no account, no cloud, no audio ever leaves your Mac.

Mumble is two things in one:

- A **windowed transcription manager**: record, get a cleaned transcript with timestamped
  segments, play it back with a synced playhead, search your library, and keep notes.
- A **global push-to-talk dictation tool**: hold a hotkey anywhere, speak, release, and the
  cleaned text is pasted straight into whatever app you're using.

![Flow](docs/screenshot.png)

## Features

- On-device speech-to-text via WhisperKit (downloads the model on first use).
- Window recording with a record orb, live waveform, and automatic transcription.
- Global push-to-talk dictation with a floating overlay capsule — hold the **Right Option (⌥)** key.
- Menu-bar control: click the menu-bar icon → **Start/Stop Dictation** to dictate hands-free
  on top of any app and paste at the cursor (no window required).
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

## Install to /Applications

To run Mumble as a normal installed app (not just from Xcode):

```bash
./scripts/install.sh
```

This generates the project, builds **Release**, ad-hoc signs it (no Apple Developer account
needed), copies `Mumble.app` to `/Applications`, clears the Gatekeeper quarantine flag, and
launches it. From then on Mumble lives in your Applications folder and the menu bar.

> Because the app is ad-hoc signed, macOS ties Accessibility / Input Monitoring grants to the
> build's signature. If you re-run the installer after code changes, you may need to re-grant
> those once in System Settings.

Alternatively, in Xcode: **Product → Archive → Distribute App → Custom → Copy App**, or just
build and drag `Mumble.app` from the Products group into `/Applications`.

## Using it from the menu bar

Mumble runs as a menu-bar app. Hold the **Right Option (⌥)** key anywhere, speak, then release —
the cleaned text is pasted into whatever app and text field has focus. You can also click the
menu-bar icon and choose **Start / Stop Dictation** for a hands-free toggle.

The Right Option hotkey requires **Input Monitoring** permission; pasting requires
**Accessibility**. Both are requested during onboarding.

## First run

On first launch, an onboarding flow walks you through granting permissions and downloading a
speech model (you can download several at once, each with its own progress). **Base** (~145 MB)
is the quick default; **Large v3 Turbo** is the most accurate on Apple Silicon. Mumble won't
record until at least one model is downloaded, and it tells you if a selected model is missing.
Pick a different model in **Settings → Models** — `Large v3 Turbo` is recommended for the best
accuracy/speed on Apple Silicon.

## Permissions

Mumble asks for three macOS permissions (manage them in **Settings → Permissions**):

| Permission | Why | Where |
| --- | --- | --- |
| **Microphone** | Record audio to transcribe | prompted in-app |
| **Accessibility** | Paste dictated text into other apps (synthesized `⌘V`) | System Settings → Privacy & Security → Accessibility |
| **Input Monitoring** | Global push-to-talk hotkey | System Settings → Privacy & Security → Input Monitoring |

> Accessibility/Input-Monitoring grants are tied to the signed binary at a specific path.
> If you move the app or rebuild with a different signature, re-grant the permission.

## Why it's not sandboxed

Pasting into arbitrary apps uses `CGEvent.post` to synthesize `⌘V`, which is **blocked by the
App Sandbox with no entitlement workaround**. Mumble therefore ships **non-sandboxed**
(Developer ID + Hardened Runtime + notarization for distribution). This is standard for
dictation utilities and rules out Mac App Store distribution.

## Running an unsigned release

If you distribute an unsigned `.zip`/`.dmg` (no Apple Developer account), Gatekeeper will warn
on first open. Users can bypass it with:

- **Right-click the app → Open → Open**, or
- `xattr -dr com.apple.quarantine /Applications/Mumble.app`

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
