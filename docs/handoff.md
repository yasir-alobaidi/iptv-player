# Handoff — 2026-09-16 (session 9)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Nothing is blocked. Phase 1 steps 1, 2, 3a, 3b and 4 are done and committed
locally; **nothing is pushed yet** — five commits are waiting (step 2 through
this one). Step 5 (the drift database skeleton) needs no hardware and no TV.

One thing only you can check: **window_manager #585, the crash when the window
is closed.** This laptop is on Wayland and nothing here can close a window from
a script, so it is still unverified. Run the app, close it with the title-bar
X, and see whether it exits quietly:

```
flutter run -d linux            # then close the window with the mouse
tail ~/.local/share/io.github.yasiralobaidi.iptvplayer/logs/app.log
```

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 1 steps 1–4 are done. Do step 5 (data/db: drift schema v1, sources and settings tables,
SettingsRepository, migrations) as written in docs/plans/phase-1-foundation.md, and stop for my
review when it's finished.
```

## Where things stand
- **Phase 0 done, GO for Linux accepted** (ADR-007). Windows playback is still
  unverified — no PC yet.
- **Phase 1 step 1:** app scaffold, every ADR-002 package, lints, `build.yaml`.
- **Phase 1 step 2:** `Result`/`AppFailure`, `redact()`, logging with our own
  rotation, global error handlers, background isolates, `bootstrap()`.
- **Phase 1 step 3a:** bundled variable fonts, `AppTokens` as a
  `ThemeExtension`, the dark theme, the focus system, the basic components,
  and the Component Gallery.
- **Phase 1 step 3b:** the canvas icon set and the media, overlay, casting and
  download components.
- **Phase 1 step 4:** the router, the desktop shell, the global shortcuts, the
  placeholder screens and the window plumbing.
- 208 tests pass; `flutter analyze`, the format check and
  `flutter build linux --debug` are clean. The app runs and shows the shell.

## Done this session (2026-09-16)
- `lib/app/destinations.dart`: the eight rail destinations with their icons
  and shortcut labels. `index` is the enum's own index, which is also the
  router's branch order.
- `lib/app/router.dart`: `StatefulShellRoute.indexedStack`, one branch per
  destination, `/search` as a non-opaque overlay route, `/dev/gallery` behind
  `galleryEnabled`. `buildRouter()` makes its navigator keys locally, so a
  test can build more than one router.
- `lib/app/shell/`: `DesktopShell`, `NavRail` (72/240, app mark, active
  indicator bar, collapse toggle), `ShellTopBar` (64 px, title, source chip,
  search field, sync and download slots, cast button), `ToastHost` and
  `shell_state.dart`.
- `lib/app/shortcuts.dart`: Ctrl+1…7, Ctrl+, , Ctrl+K, `/`, Esc — wrapped
  around the router's navigator so they work on every route.
- `lib/app/placeholder_screen.dart` and `lib/features/*/presentation/`:
  a screen for every destination, each an `EmptyState` saying which phase
  builds it, with "Add a source" as the next step.
- `lib/app/failure_message.dart`: `AppFailure` → the human line from docs/05.
- `lib/core/platform/window_bounds.dart` and `lib/app/window_setup.dart`:
  the bounds model, the store interface, `resolveStartupBounds()`, and the
  window_manager wiring (1024 × 640 minimum, debounced saves).
- `FocusPaneController` gained `focusFirst()`, `focusPane()`, `items` and
  `hasFocus`, which is what Left/Right between panes uses.
- `docs/progress.md` updated, including the running ADR-008 list.

## Instructions for the next session
1. Step 5 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. **Two things are waiting for step 5's settings table:**
   `windowBoundsStoreProvider` in `lib/app/shell/shell_state.dart` (override
   it in `bootstrap()` the way the in-memory one is overridden now, and the
   window size starts being remembered), and `railExpandedProvider`, which
   resets to collapsed on every launch until it is persisted.
3. The shell's other slots — `shellSourceProvider`, `shellSyncStatusProvider`,
   `shellDownloadsProvider`, `shellCastSessionProvider` — are deliberately
   empty. Override the provider in the phase that owns the data rather than
   changing the shell.
4. `test/app/app_harness.dart` pumps the real app with a silent log and an
   uninstalled `ErrorReporter`; `pumpApp(tester, overrides: [...])` is how a
   test fills a shell slot, and `findByLabel('…')` finds an icon-only
   control. Don't call `pumpApp` twice in one test — Riverpod refuses a
   change in the number of overrides.
5. The placeholder screens are meant to be replaced, not extended. When a
   phase builds its real screen, delete the `PlaceholderScreen` call and keep
   the file and route.
6. Commit messages carry no trailers. Commit locally; the user pushes.
7. At the end: analyze, format check, `flutter test`, update
   `docs/progress.md`, overwrite this file, and commit.

## Don't reopen without new evidence
- Flutter + media_kit for desktop with the patched `media_kit_video` in
  `third_party/` (ADR-001, ADR-003). fvp only if Windows fails.
- Casting through our own Cast v2 client, the Default Media Receiver and a
  bundled FFmpeg relay (ADR-004). H.264 → HLS/TS; HEVC → one continuous
  fragmented MP4.
- Package choices in ADR-002; downloads and the local library are in v1
  (ADR-005); discovery is bonsoir with multicast_dns as the proven fallback
  (ADR-006).
- The focus ring is stroked outside the control, not a box shadow, and it
  inverts to the primary text colour on accent-filled surfaces.
- `FocusPane` is a traversal group, not a `FocusScope`.
- Global shortcuts wrap the router's navigator, not the shell: the shell's
  own `Shortcuts` would never fire over the search overlay.
- Search is a route, not a dialog, so Ctrl+K, Esc and back agree with each
  other.
- The canvas beats docs/05 on token values; docs/05 gets corrected at the end
  of the phase along with ADR-008.

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
