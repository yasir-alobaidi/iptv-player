# IPTV Player — Claude Code project guide

Personal IPTV player. Desktop first (Linux + Windows), Google TV (Android TV) second.
Priorities, in order: **stable → fast → beautiful → feature-rich**.

Before any work, read:
- `docs/progress.md` — where the project is (update it at the end of every session)
- `docs/handoff.md` — the latest session handoff (overwrite it at the end of every session)
- `docs/08-phases-and-prompts.md` — the phase being worked on
- The spec doc for the area you touch (map below)

## Doc map
| Area | Doc |
|---|---|
| Goals, scope, platforms, success criteria | docs/00-overview.md |
| Code structure, layers, packages, interfaces | docs/01-architecture.md |
| Xtream / M3U / XMLTV, database, sync | docs/02-providers-and-data.md |
| Desktop playback (libmpv), watchdog, zapping, VOD | docs/03-playback.md |
| Chromecast sender + FFmpeg relay | docs/04-casting.md |
| UI/UX: tokens, components, screens, shortcuts | docs/05-design-system.md |
| Stability, testing, fake provider, perf budgets, CI | docs/06-quality.md |
| Google TV version | docs/07-google-tv.md |
| Downloads, local library, offline playback | docs/09-downloads-and-library.md |
| Environment setup | docs/setup.md |
| Decision log (ADRs) | docs/decisions.md |

Visual reference: the Claude Design canvas linked at the top of docs/05-design-system.md.
Read it with the Artifact tool (action: read) before building or changing UI.

## Stack
Flutter (stable) + Dart 3 · Riverpod (code-gen) · go_router · drift (SQLite + FTS5) · dio ·
freezed/json_serializable · media_kit (libmpv) for desktop playback · bundled FFmpeg/ffprobe subprocess relay ·
own Cast v2 client (TLS + protobuf) · bonsoir (mDNS) · shelf (local HTTP) · window_manager · flutter_secure_storage.
Exact packages and versions are confirmed in Phase 0 and recorded in docs/decisions.md (ADR-002).

## Commands
- `flutter pub get`
- `dart run build_runner build --delete-conflicting-outputs` (after changing freezed/drift/riverpod/json code)
- `flutter analyze` · `dart format --set-exit-if-changed .`
- `flutter test` (unit/widget/golden) · `flutter test integration_test` (integration, needs fake provider)
- `flutter run -d linux` · `flutter run -d windows`
- `dart run tools/fake_provider/bin/server.dart --port 8899` (fake IPTV server, see docs/06-quality.md)

## Hard rules
1. **Never crash on provider data.** Parsing is tolerant (numbers as strings, "" as null, [] vs {}). Bad rows are skipped and logged, never thrown to the UI.
2. **Never block the UI isolate.** M3U/XMLTV parsing, sync, and bulk DB writes run in background isolates. Long lists are virtualized.
3. **Never log secrets.** Passwords and credential-bearing URLs pass through `redact()` before any log, error message, or diagnostics export. Credentials live only in flutter_secure_storage.
4. **Every screen has loading, empty, error, and offline states.** No blank screens, no raw exception text in UI.
5. **Keyboard-first.** Every interactive element is reachable with arrows/Tab, activated with Enter/Space, dismissed with Esc, and shows the focus state from the design system. This is also the Google TV foundation.
6. **UI never imports media_kit, drift, dio, sockets, or Process.** Presentation code talks to domain interfaces (PlayerEngine, CastService, repositories).
7. **Respect provider limits.** One active stream per source unless `max_connections` allows more; downloads count as streams and yield to playback. Sync requests are serialized with backoff.
8. **External processes are supervised.** Every FFmpeg/ffprobe process has an owner, a timeout or watchdog, a PID file, and cleanup on exit and on next launch.
9. **Design tokens only.** No hard-coded colors, sizes, radii, durations, or text styles outside `lib/design/`.
10. **Tests ship with features.** Parsers get fixture tests (including malformed data), state logic gets unit tests, screens get widget tests for every state, key flows get integration tests against the fake provider.
11. **Never damage files.** Downloads write to `.part` and rename only after verification. The app never renames, moves, or changes files in folders the user added to the library; Delete is always confirmed and goes to the system trash when possible.

## Conventions
- Feature-first folders: `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core`, `lib/data`, `lib/design`.
- Riverpod code-gen providers; no global mutable singletons; dispose resources with `ref.onDispose`.
- Repositories return sealed `Result<T>` types; no exceptions across layers.
- Models are immutable (freezed). DB rows map to domain models inside repositories.
- Files `snake_case.dart`, types `PascalCase`, members `camelCase`.
- Small steps. After each step: analyze + format + tests, then commit with a clear message.
- If a spec is wrong or ambiguous, stop and ask; record the answer in docs/decisions.md.

## End of every session
1. `flutter analyze`, `dart format`, `flutter test` are clean.
2. Update `docs/progress.md` (done, in progress, next, known issues, measurements).
3. Record new decisions in `docs/decisions.md`.
