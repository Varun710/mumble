# Mumble — Implementation Plan: Voice Commands, Corrections, Snippets, Hotkey & Style Presets

**Audience:** Cursor (and the engineer driving it). This is an engineering spec, not marketing copy. Implement in the phase order given. Every phase ships independently and is gated behind a toggle with a deterministic fallback.

**Target:** Apple Silicon, **M3+** for AI features. **macOS 26 (Tahoe)+** for the Foundation Models path, with an MLX fallback for older OS / power users.

**Non-negotiables:** 100% on-device, fast (sub-second end-to-end on a normal utterance), secure (no network, no editing the user's foreground app), and graceful (any AI failure falls back to the existing deterministic cleanup — never corrupts output).

---

## 0. The one architectural idea

"Strike that," "new paragraph," and self-corrections are **not three features**. They are one post-ASR interpretation pass over the full utterance. Wispr Flow ships them as two named halves (Backtrack = corrections, Smart Formatting = commands) but both run in a single step. Style presets (Formal/Email/Code) are the _same_ pass with a different instruction block.

So we build **one component — the `Interpreter`** — and everything else is configuration fed into it. Snippets and the hotkey are independent and don't touch the model at all.

```
Audio ─► ASR (Parakeet, word timestamps) ─► Snippet pre-pass (deterministic)
       ─► Pause-marker injection ─► Interpreter (LLM) ─► Guardrail ─► Paste
                                         ▲                    │
                                         └── style preset     └── on fail / timeout: deterministic cleanup
```

Because the Interpreter only ever produces **the string we are about to paste** (decision locked: commands apply _within the current utterance, before paste_ — we never touch already-pasted text), the worst possible failure is "fell back to the old cleanup." Nothing in the user's document can be corrupted. This is what makes an LLM-does-everything design safe to ship.

---

## 1. Model stack — the "best / fastest / accurate, balanced" decision

Two models, each chosen for its layer. Both run on the Apple Neural Engine, fully offline.

### 1.1 ASR layer → **Parakeet TDT 0.6B v3** (via FluidAudio, Swift/ANE)

Recommended even if Mumble already bundles Whisper — keep Whisper as the multilingual fallback, make Parakeet the default English/European engine.

Why it's the balanced winner:

- **Accuracy:** Tops the Hugging Face Open ASR leaderboard (~6.32% WER vs Whisper Large V3's ~7.44%).
- **Speed:** ~an order of magnitude faster than Whisper Large V3 on Apple Silicon — text lands the instant the key is released, which is the whole feel of push-to-talk.
- **Word-level timestamps** via the TDT decoder. **This is the linchpin** — the pause-detection trick in §3 is impossible without per-word timings.
- **Silence behaves like silence.** Transducer architecture emits nothing during pauses instead of hallucinating ("Subtitles by Amara.org"). Critical for "always-listening" feel where users stop to think.
- **Disfluency handling:** benchmarks show it already drops fillers / reconstructs restarts better than Whisper or Apple's engine on real (non-read-aloud) speech.

Limits: 25 European languages only (no CJK/Arabic/Hindi). **Mitigation:** route those languages to the existing Whisper engine via the model manager. Word timestamps are weaker on Whisper, so the pause-marker feature degrades gracefully to a fixed-heuristic on those languages (see §3.4).

Integration: `FluidAudio` is the native Swift framework that runs Parakeet on the ANE. Confirm the current API for `transcribe()` returning per-word `{text, startTime, endTime}` against its repo before wiring §3.

### 1.2 Interpreter layer → **Apple Foundation Models** (primary) + **MLX-Swift Qwen** (fallback)

This is the corrections/commands/style brain.

**Primary: Apple Foundation Models framework (macOS 26+).**

- System-managed **~3B on-device** model — _nothing to bundle, nothing to download_, ships with the OS, free, offline, runs on ANE.
- **`@Generable` guided generation** gives us **typed, constrained Swift output** instead of a string to parse — the model is forced at the token level to emit valid structure. This is exactly what we want for a structured "cleaned text + applied-commands" result.
- `LanguageModelSession.prewarm()` to hide first-token latency (call on hotkey-down, before the user finishes speaking).
- `SystemLanguageModel.default.availability` gate (`deviceNotEligible` / `appleIntelligenceNotEnabled` / `modelNotReady`).
- Context window is small — fine, our inputs are one utterance.

**Fallback / power route: MLX-Swift + Qwen 3.5 2B (4-bit), or Llama 3.2 3B (4-bit).**

- For macOS < 26, Apple-Intelligence-disabled devices, or users who want a heavier/custom model.
- MLX-Swift has native Swift bindings and ~60 tok/s decode on a 2B/M-series — a ~30-word utterance is well under a second.
- Slots into the existing model manager (download, pick, swap). Use constrained/JSON-mode decoding to mirror the `@Generable` contract.

**Why not "one big model for everything":** ASR and instruction-following are different jobs; a dedicated transducer ASR is both faster and more accurate than asking an LLM to transcribe, and the 3B interpreter is far cheaper than a 7B+ for the narrow rewrite task. Two specialists beat one generalist here on every axis (speed, accuracy, memory).

> **Cursor:** Build the Interpreter behind a `protocol InterpreterBackend`. Ship `FoundationModelsBackend` and `MLXBackend` as two conforming types selected at runtime by availability. Phase 1 only needs one working backend — start with whichever the dev machine supports.

---

## 2. Module / file layout

Add a new feature area; do not entangle with existing cleanup code (it becomes the fallback, kept intact).

```
Mumble/
├─ Interpret/
│  ├─ Interpreter.swift              // orchestrator: pre-pass → backend → guardrail → result
│  ├─ InterpreterBackend.swift       // protocol
│  ├─ FoundationModelsBackend.swift  // Apple FM, @Generable schema
│  ├─ MLXBackend.swift               // MLX-Swift fallback
│  ├─ InterpreterResult.swift        // @Generable typed output struct
│  ├─ Prompt.swift                   // system prompt + few-shots + style blocks
│  ├─ PauseMarkers.swift             // word-timestamps → <pause> injection
│  └─ Guardrail.swift                // validate LLM output vs input; decide accept/fallback
├─ Snippets/
│  ├─ SnippetStore.swift             // trigger → expansion, persisted
│  └─ SnippetExpander.swift          // deterministic pre-pass
├─ Hotkey/
│  └─ RightOptionHotkey.swift        // CGEventTap on flagsChanged, keycode 61
├─ Styles/
│  ├─ StylePreset.swift              // enum + per-preset instruction block
│  └─ AppContextRouter.swift         // frontmost app bundleID → preset
└─ Cleanup/  (existing — now also the fallback path)
```

---

## 3. Phase 1 — Corrections + Commands (the intelligent core) ⭐ build first

This is the differentiator. Everything below is one pass.

### 3.1 Typed output contract

```swift
import FoundationModels

@Generable
struct InterpreterResult {
    @Guide(description: "The final cleaned text to paste. Self-corrections resolved, \
inline commands executed, filler removed, punctuation/casing fixed. \
NEVER include meta-commentary, only the text the user wants pasted.")
    var text: String

    @Guide(description: "True only if the user said a whole-utterance command like \
'start over' / 'scratch all that' meaning discard everything.")
    var discardAll: Bool
}
```

The MLX backend mirrors this as a strict JSON schema (`{"text": "...", "discardAll": false}`) with constrained decoding; parse and validate.

### 3.2 The Interpreter orchestrator

```swift
struct Interpreter {
    let backend: InterpreterBackend
    let cleanup: DeterministicCleanup     // existing pipeline = fallback
    let timeout: Duration = .milliseconds(600)

    func interpret(_ asr: ASRResult, style: StylePreset) async -> String {
        // 1. snippet expansion already done upstream (pre-pass)
        // 2. inject pause markers from word timestamps
        let marked = PauseMarkers.inject(asr)            // string with <pause> tokens
        // 3. LLM pass with timeout
        do {
            let result = try await withTimeout(timeout) {
                try await backend.run(input: marked, style: style)
            }
            if result.discardAll { return "" }
            // 4. guardrail
            guard Guardrail.accept(input: asr.plainText, output: result.text) else {
                return cleanup.run(asr.plainText)        // fallback
            }
            return result.text
        } catch {
            return cleanup.run(asr.plainText)            // timeout / model error → fallback
        }
    }
}
```

### 3.3 Command surface (Phase 1 set)

The model is instructed (prompt + few-shots) to handle, all within the utterance:

- **Self-corrections — trigger words:** "actually", "I mean", "no wait", "sorry", "make that", "scratch that".
  - `Let's do coffee at 2 actually 3` → `Let's do coffee at 3.`
- **Self-corrections — bare restatement (the hard one):** `email Peter, sorry email Benjamin` → `Let's email Benjamin.` Regex can't do this; this case is _why_ we chose an LLM over a rules engine.
- **Structural:** "new paragraph" / "new line" (→ `\n\n` / `\n`), "strike that" / "scratch that" (drop the last clause or sentence), "delete that" (drop last few words), "start over" (→ `discardAll = true`).
- **Inline punctuation / casing:** "period", "comma", "question mark", "exclamation point", "all caps", "new bullet".
- **Leave-alone discipline:** `I actually enjoyed the movie` must be preserved — "actually" is only a correction when context says so. The model uses the _full_ utterance + pause markers as context, exactly like Backtrack does.

### 3.4 Pause markers — the literal-vs-command disambiguator ⭐

The single highest-leverage trick. The same words are literal or a command depending on whether a pause preceded them ("...start a **new paragraph** in chapter two" = literal vs. "...that's the intro. _[pause]_ **New paragraph.** Now the body" = command). Wispr's own docs confirm commands like "new line" require a noticeable pause or they're treated as literal text.

```swift
enum PauseMarkers {
    static let threshold: Duration = .milliseconds(450)   // tune 400–550ms

    static func inject(_ asr: ASRResult) -> String {
        var out = ""
        var prevEnd: Duration? = nil
        for w in asr.words {
            if let p = prevEnd, (w.start - p) >= threshold { out += " <pause> " }
            out += w.text + " "
            prevEnd = w.end
        }
        return out.trimmed
    }
}
```

The prompt tells the model: _`<pause>` marks a silence; a command word right after `<pause>` is almost certainly a command, the same word mid-flow is almost certainly literal._

Degradation: on engines without reliable word timings (Whisper path), skip injection and rely on trigger-word + context only. Slightly worse literal/command separation, still functional.

### 3.5 System prompt + few-shots

Keep in `Prompt.swift`. Temperature ~0. Put the system prompt + few-shots in a **cached prefix** (FM session reuse / MLX KV-cache) so prefill is near-free per utterance. Sketch:

```
You convert raw dictation into the exact text the user wants pasted.
Rules:
- Remove fillers (um, uh, like) and false starts.
- Resolve self-corrections: keep only the user's final intent. Triggers include
  "actually", "I mean", "no wait", "sorry", "make that", "scratch that", or a bare restatement.
- Execute inline commands: "new paragraph"/"new line", "strike that", "delete that",
  "start over", spoken punctuation, "all caps".
- <pause> marks a silence. A command word right after <pause> is a command;
  the same word mid-sentence with no pause is literal — keep it as text.
- Fix punctuation, capitalization, obvious grammar. Do NOT invent content or answer questions.
- Output ONLY the final text. No preamble, no explanation.

[6 few-shot pairs covering: trigger correction, bare restatement, new-paragraph-as-command,
 new-paragraph-as-literal, strike-that, start-over → discardAll]
```

### 3.6 Guardrail (makes LLM-everything safe)

```swift
enum Guardrail {
    static func accept(input: String, output: String) -> Bool {
        guard !output.isEmpty else { return false }
        // 1. length sanity: cleaned output shouldn't balloon or vanish
        let r = Double(output.count) / Double(max(input.count, 1))
        guard r > 0.25 && r < 1.6 else { return false }   // tune
        // 2. cheap similarity: token overlap with input (model shouldn't go off-script)
        guard tokenOverlap(input, output) > 0.45 else { return false }
        // 3. no meta-leak: reject if output contains telltale preamble
        guard !output.localizedCaseInsensitiveContains("here is the") else { return false }
        return true
    }
}
```

Plus the hard **600 ms timeout** in the orchestrator. Either guard failing → deterministic cleanup. Log fallbacks (locally) so you can tune thresholds.

### 3.7 Phase 1 — Definition of Done

Dictate: _"Let's meet Tuesday um actually Friday. [pause] New paragraph. Send the deck to Peter, sorry, to Benjamin."_ →

```
Let's meet Friday.

Send the deck to Benjamin.
```

…and the literal control case _"I actually enjoyed the new paragraph I wrote"_ passes through unchanged. Latency < 1 s on M3. Kill-switch toggle returns to current behavior exactly.

---

## 4. Phase 2 — Snippets + Right-Option hotkey (quick wins, this week)

Both are LLM-independent and shippable in days.

### 4.1 Snippets (voice text-expansion)

Trigger phrase → canonical text, run as a **deterministic pre-pass before the Interpreter** so it's fast and predictable. Reuse the existing custom-dictionary persistence.

```swift
struct SnippetExpander {
    let store: SnippetStore   // [normalizedTrigger: expansion]
    func expand(_ text: String) -> String {
        // normalize (lowercase, strip punctuation), match whole-phrase triggers,
        // replace with expansion. Keep it dumb; let the Interpreter handle anything fuzzy.
    }
}
```

Examples: "my email address" → `sid@example.com`; "standard disclaimer" → `[full block]`. Settings UI: list + add/edit/delete, mirroring the dictionary screen.

DoD: speaking a trigger pastes the full expansion verbatim; non-triggers untouched; expansion still flows through cleanup/Interpreter so surrounding speech is handled.

### 4.2 Right-Option-only hotkey

`CGEventTap` on `flagsChanged`, watch keycode **61** (`kVK_RightOption`).

The subtlety: distinguish a **solo** Right-Option tap/hold (→ dictation) from Right-Option used as a **modifier in a chord** (→ pass through untouched). Pattern:

```swift
final class RightOptionHotkey {
    // on flagsChanged:
    //   - Right-Option pressed AND no other modifier flags set AND no other key down
    //       → start dictation (and FoundationModels prewarm())
    //   - if any other key/flag fires before release
    //       → cancel dictation, re-emit the event so the OS sees a normal modifier
    //   - on Right-Option release → stop dictation, run pipeline
}
```

Notes: requires Accessibility/Input-Monitoring permission (already needed for paste-anywhere). Make the binding configurable later, but Right-Option-only is the default ask. Prewarming the model on key-down is free latency savings.

DoD: tap-hold Right-Option → records → release → pastes. `⌥+C` etc. still produce a normal Option chord. No stuck modifier state.

---

## 5. Phase 3 — Style presets (Formal / Email / Code) + auto-routing

Pure prompt-template layer over the **same Interpreter** — no new engine.

```swift
enum StylePreset: String, CaseIterable {
    case neutral, formal, email, code, casual
    var instruction: String { /* block appended to system prompt */ }
}
```

- **Formal:** full sentences, no contractions, no slang.
- **Email:** greeting/sign-off awareness, paragraph breaks, professional tone.
- **Code:** **do not prose-format** — preserve symbols/identifiers, suppress filler-stripping that could eat tokens like "dot", "open paren"; keep it literal.
- **Casual:** light touch, contractions OK.

Auto-routing (Wispr's "adapts tone by app, no config"): read frontmost app via `NSWorkspace.shared.frontmostApplication.bundleIdentifier`, map to a preset, user-overridable.

```swift
struct AppContextRouter {
    static let map: [String: StylePreset] = [
        "com.apple.mail": .email,
        "com.microsoft.VSCode": .code,
        "com.apple.dt.Xcode": .code,
        "com.tinyspeck.slackmacgap": .casual,
        "com.google.Chrome": .neutral,
    ]
    func preset(forFrontmostBundleID id: String?) -> StylePreset {
        guard let id else { return .neutral }
        return Self.map[id] ?? .neutral
    }
}
```

DoD: same dictation pasted into Mail vs. VS Code comes out tone-appropriate; a manual preset picker overrides the auto choice; Code mode never mangles symbols.

---

## 6. Cross-cutting requirements

**Performance budget (M3, ~30-word utterance):**
| Stage | Target |
|---|---|
| ASR (Parakeet, on release) | < 200 ms |
| Snippet + pause inject | < 5 ms |
| Interpreter (FM/MLX, prewarmed) | < 500 ms |
| Guardrail + paste | < 20 ms |
| **End-to-end (release → paste)** | **< 750 ms** |

`prewarm()` on hotkey-down removes cold-start from the critical path. If you ever exceed budget, the timeout fallback keeps it bounded.

**Security / privacy:**

- No network in the interpret path — assert it in tests (both models are on-device).
- We never read or edit the foreground app's existing text. Commands resolve _inside our buffer_, then a single paste. No Accessibility-tree surgery, nothing destructive to undo.
- Snippets/dictionary stored locally (existing store); never synced without explicit user action.

**Failure philosophy:** every AI stage has a deterministic fallback. The app must be _strictly better than today_ with AI on, and _identical to today_ with AI off or on failure.

---

## 7. Suggested build order for Cursor

1. **Skeleton + fallback wiring first.** `Interpreter` orchestrator that currently just calls existing `cleanup.run()`. Prove the seam, no model yet.
2. **PauseMarkers** + unit tests against synthetic word-timestamp fixtures.
3. **One `InterpreterBackend`** (whichever the dev machine supports — FM on macOS 26, else MLX). Wire `@Generable` / JSON schema. Get §3.7 passing.
4. **Guardrail** + timeout; force-fail the model in a test and confirm clean fallback.
5. **Right-Option hotkey** + **Snippet pre-pass** (parallelizable, independent).
6. **Second backend** so both OS paths work; runtime selection by `availability`.
7. **Style presets** + app router.

Land each behind a feature flag. Don't optimize prompts until §3.7 passes end-to-end — correctness of the pause/guardrail machinery first, prompt polish second.

---

## 8. Things to verify against current docs before coding (fast-moving APIs)

- **FluidAudio**: exact `transcribe` return type and that per-word `start`/`end` timestamps are exposed (TDT decoder). The whole pause feature depends on it.
- **Foundation Models**: `SystemLanguageModel.default.availability` cases, `LanguageModelSession.respond(to:generating:)` signature, `prewarm()`, and current `@Generable` / `@Guide` macro surface for macOS 26.x.
- **MLX-Swift**: current package name, model-loading API, and constrained/JSON decoding support for the chosen Qwen/Llama build.

Pin versions once verified; these three are the parts most likely to have shifted since this plan was written.
