# Changelog

<!-- Maintained with AI Dashboard. Format per entry:
##  YYYY-MM-DD: Title [status]      (status = planned | in_progress | done)
Purpose: one line on why (optional)
A few lines on what it does (optional)

Newest entries on top. The dashboard imports new entries from this file. -->

## 2026-06-23: Rename to Zan and prep for public release [done]
Purpose: share the app publicly on GitHub.
Renamed the app from mk.ai to Zan (bundle id dev.local.zan), removed the
personal "Translate to Danish" transform, switched to ad-hoc signing by default,
and added a public README plus MIT LICENSE. Confirmed no API keys are committed
(key lives in the Keychain).

## 2026-06-21: Initial build [done]
Purpose: fast, no-fluff voice + text AI from the macOS menu bar.
Menu-bar dictation (toggle / hold-to-talk) with live recording HUD, OpenAI
transcription with optional AI cleanup, text transforms that replace the
selection (proofread, make professional, strip em dashes, custom), read-only
popups (translate to English, summarize), an Open-in-r.jina.ai URL action,
in-app Recent activity history, permissions panel, and launch at login.
