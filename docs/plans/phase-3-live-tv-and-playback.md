# Phase 3 — Live TV, the player, the watchdog: plan

**Status: approved 2026-09-19** — the recommendation in all six decisions, and the four overlay sketches. For decision 1: before any stream from your provider I ask in a pop-up and wait for your yes (you free the connection first).

## Context
Phase 2 left the catalogue in the database: sources, credentials in the keyring, a sync engine, and the categories the user picked (ADR-009). Nothing plays yet. Phase 3 makes the app an IPTV player: the Live TV screen, a full-screen player, and the watchdog that keeps a live stream alive through drops, stalls and provider faults.

Exit criteria (docs/08): every fault test passes · the zap budget is met (p50 ≤ 1.5 s, p95 ≤ 3 s on the fake provider) · a 1-hour soak is clean (the 8-hour soak waits for the release).

What Phase 3 does **not** own: XMLTV and the guide grid (Phase 4), movies, series and resume prompts (Phase 5), search polish (Phase 6), casting (Phase 7: Cast buttons are not shown until then), downloads (Phase 8).

Carried in, not to be relitigated without new evidence:
- **ADR-003:** media_kit with our patched media_kit_video (`third_party/`), system libmpv 0.34.1, zero-copy VA-API on native Wayland; never force the X11 backend. Every option and property name in docs/03 is verified against 0.34.1. The Phase 0 spike measured zap p50/p95 at 320/597 ms over loopback.
- **ADR-008/009:** the UI never imports media_kit (hard rule 6: `PlayerEngine` is the seam, and `layering_test` enforces it); credentials are rebuilt into URLs only at play time (`fillUrl`, `credentialsFor`), never stored or logged; errors show our words plus what the server answered (`serverAnswer`).
- **Your provider:** Xtream, TS and HLS allowed, **`max_connections` 1**, and during the Phase 2 run another device was using that one connection.

Working rhythm, as before: one numbered step at a time; after each, analyze + format + tests, a local commit without trailers, and a stop for your review.

## Decisions (my recommendation first in each)
1. **Playing from your real provider.** Your account allows one stream, and another device was on it. When the app opens a stream, the panel will either refuse it or cut the other device off. **Recommendation:** I never play from your provider unless you have said in that session that the other device is off. The opt-in real-provider test gets a `"play": true` switch in the login file: it plays one channel for 20 s, zaps once, and checks that the connection is released. Everything else runs against the fake provider.
2. **Now / next before the guide exists.** The preview pane and the channel banner want "now" and "next". XMLTV is Phase 4. **Recommendation:** use Xtream's `get_short_epg` for the channel in the preview and its immediate neighbours only: fetched lazily, cached for 5 minutes, one request at a time. M3U sources show "No guide information" until Phase 4. The alternative is to show nothing until Phase 4.
3. **Schema v4: favorites, watch history, hidden channels.** Phase 2 left `favorites` and `watch_history` to "the phases that write them", and Phase 3 writes both: the F key, and Backspace for last channel. Hiding a channel from the context menu needs a column as well. **Recommendation:** one migration now, `favorites` and `watch_history` as docs/02 specifies plus `channels.is_hidden`, with a v3 → v4 migration test on a populated database.
4. **Real libmpv in CI.** The watchdog's logic is unit-tested against a fake engine with a fake clock, and CI runs that. The fault suite needs a real libmpv against the fake provider. CI has libmpv and xvfb but no GPU. **Recommendation:** step 1 spikes the patched media_kit under xvfb. If it can't render there, CI runs the fault suite with mpv's video output off (`vo=null`; demux, network and audio behave the same), and the laptop runs the suite with real video before the phase exit.
5. **Settings → Playback in this phase.** The buffer presets (docs/03) only mean something if they can be chosen. **Recommendation:** a small Playback page now: buffer preset, deinterlace (Auto/On/Off), preferred audio and subtitle languages, live format (TS/HLS) and the User-Agent override. Hardware decoding stays on `auto-safe` with no switch until someone needs one.
6. **The 1-hour soak.** It must run the real player; under xvfb, decoding happens in software and the CPU numbers mean nothing. **Recommendation:** I run it on your screen at a time you pick. It opens a window for an hour and logs memory and CPU every minute. The alternative, under xvfb, only proves "no crash, no leak".

## Step 1 — PlayerEngine and the media_kit engine
- `PlayerEngine` in `lib/core/player/` (domain only): open(url, headers, options), stop, pause/resume, volume/mute, audio/subtitle track selection, aspect; a stream of `PlayerEvent`s (state, position, cache duration, video params, tracks, first frame, EOF, error with mpv's text) and a snapshot for the stream-info overlay (`hwdec-current`, codecs, fps, dropped frames).
- `MediaKitPlayerEngine` in `lib/data/player_mediakit/`: the base options and the three buffer presets from docs/03, using the property names verified in ADR-003. One instance is reused across channels (docs/03 zapping). `cache-on-disk=no` removes 0.34.1's "Failed to create file cache" log line.
- `FakePlayerEngine` for tests: scripted events, a fake clock.
- **Spike (decision 4):** the patched engine under xvfb, with and without `vo=null`; the result goes in ADR-010.
- Verify: engine contract tests on the fake; the real engine plays `h264_1080p50_aac` from the fake provider (on the laptop and under xvfb); `layering_test` still bans media_kit outside `lib/data/`.

## Step 2 — The fake provider's stream faults and HLS
- The faults `/admin/faults` already stores (docs/06) now act on `/live/…`: `drop_after_s`, `stall_after_s`, `slow_start_ms`, `http_status` (401/403/404/429/500), `max_connections` (a second stream is refused while one is open; closing frees it), `redirect_with_expiring_token`, `codec_switch_after_s`. Also per-query, so one test can fault a single channel.
- `.m3u8` live output (segmented HLS from the same loop), since the live format can be set to HLS and your panel allows it.
- The empty-404 sign-in quirk from Phase 2 also applies to streams where a panel does it.
- Verify: fake-provider tests per fault, each against a real HTTP client.

## Step 3 — URLs, the coordinator, schema v4
- `StreamUrlBuilder`: Xtream `live/{u}/{p}/{id}.ts|.m3u8` (the source's live format), the movie and series paths for Phase 5, M3U templates via `fillUrl`. The URL is always rebuilt from the source, never from a redirect (docs/02). It is built in memory at play time, and its log line goes through `redact()`.
- `PlaybackCoordinator`: the single owner of what is playing. It enforces the connection policy per source: with `max_connections` 1, stop and **wait for the close** before opening the next stream. A zap on a one-connection panel therefore closes first; the stop is measured, because it adds to zap time. It also records history (live: last watched, and the last channel for Backspace).
- Schema v4 (decision 3): `favorites`, `watch_history`, `channels.is_hidden`, with DAOs, a `ChannelRepository` (paged queries by category, favorites, filter, sort by number or name; hidden channels left out) and migration tests.
- Verify: unit tests for URLs (credentials never in a log or failure detail), the connection policy (a fake engine and a fake close delay), history, and the migration.

## Step 4 — The watchdog
- `PlaybackWatchdog`: `idle → opening → playing ⇄ buffering → reconnecting → failed` (docs/03). Open timeout from the preset (12 s Balanced), stall after 8 s without progress or 15 s of buffering, EOF on live means reconnect, backoff 1, 2, 4, 8, 15, 30 s, and after 6 attempts the failed state.
- **Classifying a failure:** mpv reports failures as log text, not HTTP statuses. When mpv fails to open, the watchdog makes one small probe request (GET, the first bytes only, then closed) after mpv has closed its connection. It reads the status the way the Xtream client does: 401/403 → account message, stop; 404 → channel offline, offer the next one; 429, a panel-specific 403, or a close while another stream is ours → connection limit, explained; 5xx → retry. The failure card shows our words and the server's answer (Phase 2's rule). An unsupported codec → stop, with details.
- The codec switch resets `frame-drop-count`; a lower count is not an error (ADR-003).
- Verify: thorough unit tests on the fake engine with a fake clock, one per transition and per error class, including "a stall during reconnecting" and "the user zaps away mid-backoff".

## Step 5 — The Live TV screen
- The canvas's `Live TV` artboard (re-read from the canvas first, in case it changed since the local copy of Sep 15): categories pane (260 px: Favorites pinned, All channels, then the visible categories with counts, type-to-filter, "N categories hidden · Manage"), channels pane (virtualized `ChannelRow`s, sticky filter, No. / A–Z sort, Enter = fullscreen, F = favorite, context menu: favorite, hide, rename), preview pane (16:9 player with LIVE and quality badges, now/next per decision 2, Watch fullscreen, Favorite).
- A move of the selection previews after 350 ms (docs/05). Only one stream is ever open (the coordinator), and the preview stops when the screen is left.
- The channel list is one Tab stop with arrows inside (`FocusPane(tabStop: true)`, Phase 2 step 8), since a category can hold thousands of channels. Left/Right moves between panes, and each pane remembers its item.
- Every state: loading skeletons, no source (to onboarding), empty category ("No channels in this category." + Show hidden), a sync running, offline, and the preview's own opening, reconnecting and failed states.
- Verify: widget tests per state, keyboard tests, goldens at 1280×800 and 1920×1080.

## Step 6 — The full-screen player
- The canvas's `Full-screen player`: the OSD hides after 3 s and returns on any input, and the cursor hides with it. Top: logo, number, name, LIVE, resolution, clock. Bottom: now/next, Audio, Subtitles, Aspect, Stream info, Exit. The ReconnectingPill ("Reconnecting… attempt 2 of 6") sits top centre.
- Zapping: ↑/↓ and PageUp/PageDown show the banner at once and open after 350 ms; digits open the number overlay (commits after 1.5 s or Enter); Backspace goes to the last channel; ← opens the channel panel; Esc leaves full screen; double-click toggles full screen; M, A, S, I per docs/05.
- The failure card (Retry / Next channel / Details) and the stream-info overlay (key I: resolution, fps, codecs, `hwdec-current`, audio, bitrate estimate, cache, dropped frames, the redacted URL).
- Verify: widget tests for the OSD timer, zap debounce, number entry, last channel, each overlay; keyboard tests.

## Step 7 — Settings → Playback
- Per decision 5; saved in `settings`, applied on the next open (the preset) or at once (languages, deinterlace).
- Verify: widget tests; the engine test checks each preset's options reach mpv.

## Step 8 — The fault suite and the real provider
- Integration tests with the real engine against the fake provider in its own process, one per fault: drop, stall, slow start, 401, 404, connection limit, expiring redirect, codec switch. Each either recovers (the stream plays again, measured) or shows the right message, including the server's answer.
- A keyboard-only walk: Live TV → move through channels (preview) → Enter (full screen) → zap ↑↓ → number entry → Backspace → channel panel → Esc.
- The real-provider test gains the `"play": true` step (decision 1).
- Verify: all green locally with real video, and in CI per decision 4.

## Step 9 — Zap benchmark, soak, phase exit
- Zap benchmark: 50 zaps alternating between samples on the fake provider; p50/p95 from the key press to the first frame, including the 350 ms debounce and the close on a one-connection source. Budget: p50 ≤ 1.5 s, p95 ≤ 3 s.
- `tools/soak`: N hours of live playback with random faults from `/admin/faults`, logging memory, CPU and watchdog events every minute. Then the 1-hour soak (decision 6), with a pass meaning no crash, every fault recovered, and memory growth within budget.
- Docs: docs/03 corrected where reality disagreed, docs/05 "As built", ADR-010 to Accepted, progress, handoff.

## Overlays with no artboard (sketches for approval)
The canvas has the Live TV screen and the full-screen player with the OSD and the reconnecting pill. These four are not on it:

**Failure card** (centre of the player, 480 px):
```
┌────────────────────────────────────────────┐
│  ⚠  This channel isn't responding          │
│     We tried 6 times. The server answered  │
│     HTTP 404 (Not Found).                  │
│                                            │
│  [ Retry ]  [ Next channel ]   Details ▾   │
└────────────────────────────────────────────┘
```
**Channel panel** (← in full screen; translucent, left edge, 360 px, the current category):
```
┌──────────────────────────┐
│ Sports · 214             │
│ 201  AS  Arena Sports 1 ◀│  ← playing
│ 202  AS  Arena Sports 2  │
│ 203  VM  Velocity Motors │
│ …                        │
│ ↑↓ move · Enter play · → close
└──────────────────────────┘
```
**Number entry** (top right):
```
            ┌──────────────┐
            │  2 0 _       │
            │  Arena Sp… 2 │   ← the match so far, if any
            └──────────────┘
```
**Stream info** (I; top left, monospace):
```
┌──────────────────────────────────────┐
│ Video   1920×1080 · 50 fps · H.264   │
│ Decode  vaapi (hardware)             │
│ Audio   AAC 2.0 · eng                │
│ Bitrate ~6.2 Mb/s · cache 7.8 s      │
│ Dropped 0                            │
│ Source  http://host/live/***/***/201.ts
└──────────────────────────────────────┘
```

## Verification (every step and at the exit)
- Every step: `flutter analyze`, the format check, `flutter test`, the fake provider's `dart test`, CI's generated-code check (`build_runner` then `git diff --exit-code`, the step that went red in Phase 2), and `flutter build linux --debug`.
- UI steps: the keyboard-only walk, and every state visited.
- Exit: the fault suite green, the zap budget met, the 1-hour soak clean, CI green.

## Risks
- **Your one connection.** Zapping on a one-connection panel has to wait for the close, and some panels count a closed connection for a few seconds. The watchdog must treat a refusal right after a zap as "wait and retry", not as a failure. Measured on the fake provider's `max_connections` with a close delay, and checked once on your panel if you allow it.
- **The patched media_kit under xvfb** (decision 4) is untested; the spike comes first.
- **mpv's error reporting is text:** the probe request is the reliable classifier, but it costs one extra request after a failure. On a one-connection panel it runs only after mpv has let go.
- **Frame and CPU numbers only mean something on the real display** (ADR-003: XWayland loses zero-copy; xvfb decodes in software).
- **Memory over hours:** one engine reused for every zap is what docs/03 asks for; the soak is what proves it doesn't leak.
