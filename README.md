# Zan

**Zan** is a native macOS menu-bar app for fast, no-fluff voice and text AI,
right where your cursor is, in any app. The name is from Japanese (斬): cut
straight to the important part.

Two things it does:

1. **Voice to text.** Press a hotkey, speak, and Zan transcribes (and optionally
   cleans up) your speech and types it at the cursor, in any app.
2. **Text actions on a selection.** Select text anywhere, press a hotkey, and Zan
   either replaces it with an AI-edited version or shows a result in a popup.

It runs in the menu bar (no Dock icon), keeps your API key in the macOS Keychain,
and sends your audio/text only to the OpenAI API calls you configure. No
telemetry.

## Features

- **Dictation** with a global hotkey, in two modes: toggle (press to start/stop)
  or hold-to-talk.
- **On-screen recording HUD** with a live waveform, plus a Stop button.
- **Optional AI cleanup** of dictated text (editable prompt) before it's inserted.
- **Text transforms** that replace the selection, each with its own hotkey and
  editable prompt:
  - Proofread
  - Make professional
  - Strip em dashes
  - …and you can add your own.
- **Read-only popups** (don't change your text):
  - Translate selection to English
  - Summarize selection (one sentence, or up to 3 bullets)
- **Open in r.jina.ai** — rewrites a selected URL to its Jina Reader form.
- **Recent activity** — an in-app history of past dictations and transforms with
  their text (copyable).
- **Permissions panel** and **launch at login** toggle.
- **Show window on launch** so the app isn't invisible the first time.

Insertion and selection-reading snapshot and restore your clipboard, so they
never clobber what you had copied.

## Requirements

- macOS 14 or later (Apple Silicon or Intel)
- An [OpenAI API key](https://platform.openai.com/api-keys) (you pay OpenAI for
  usage)
- [XcodeGen](https://github.com/yonik/XcodeGen) to generate the Xcode project
  (`brew install xcodegen`)
- Xcode 15+

## Build & run

```sh
git clone https://github.com/MangoTango234/zan.git
cd zan
xcodegen generate     # creates Zan.xcodeproj from project.yml
open Zan.xcodeproj     # then press Cmd+R
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project Zan.xcodeproj -scheme Zan -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Zan.app
```

The app is a menu-bar agent: look for the **waveform icon** at the top-right.

### Signing & permissions

By default the project is **ad-hoc signed** so it builds with no Apple account.
The tradeoff: macOS resets the Accessibility / Input Monitoring grants on each
rebuild. For grants that persist across rebuilds, build with your own signing
identity:

```sh
xcodebuild -project Zan.xcodeproj -scheme Zan -configuration Debug \
  -derivedDataPath build build \
  CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=XXXXXXXXXX
```

## First-time setup

1. Launch Zan. The window opens on first launch (toggle this off later under
   **System → Show window on launch**).
2. **OpenAI** section: paste your `sk-...` key and click **Save** (stored in the
   Keychain).
3. **Voice to Text**: set a **Trigger key** and pick a transcription model.
4. **Transforms**: set hotkeys for the actions you want.
5. Grant **Microphone** (for dictation) and **Accessibility** (to paste and read
   selections) when prompted, or from the **System** section.

## How it works

- **Transcription** posts your recorded `.m4a` to OpenAI
  `/v1/audio/transcriptions` (default model `gpt-4o-mini-transcribe`).
- **Transforms / cleanup / popups** call `/v1/chat/completions` with your editable
  prompt as the system message and your text as the user message (default text
  model `gpt-4o-mini`). Both models are editable in the UI.
- **Insertion** copies the result to the pasteboard and synthesizes Cmd+V, then
  restores your previous clipboard. It waits for hotkey modifiers to be released
  first so the paste isn't contaminated by a still-held key combo.

Transcription is behind a `Transcriber` protocol and text is behind a
`TextTransformer` protocol, so a local engine (e.g. WhisperKit) or another
provider can be added without touching callers.

## Privacy

Zan stores your API key in the macOS Keychain and your prompts/history in
`~/Library/Application Support/Zan/`. Audio and text are sent only to the OpenAI
endpoints above, for the requests you trigger. There is no analytics or
telemetry. Zan is non-sandboxed because it types into other apps and reads the
current selection, which the sandbox forbids.

## License

MIT. See [LICENSE](LICENSE).
