# Handoff — 2026-09-15 (session 8)

For the next Claude Code session on this project, and for the user starting it.

## Before you start the next session (user)
Nothing is blocked. Phase 1 steps 1, 2, 3a and 3b are done and committed
locally (`fa39217`, `e9efe17`, `9d2ad8b` and the step 1 commit); **they are
not pushed yet** — push when you're ready. Step 4 (the app shell) needs no
hardware and no TV.

## Start prompt
Open Claude Code in this folder and paste:

```
Continue the IPTV player project. Read docs/handoff.md, CLAUDE.md, and docs/progress.md first.
Phase 1 steps 1–3b are done. Do step 4 (app/: router, shell, window, shortcuts) as written in
docs/plans/phase-1-foundation.md, and stop for my review when it's finished.
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
- 156 tests pass; `flutter analyze`, the format check and
  `flutter build linux --debug` are clean. The app runs and shows the gallery.

## Done this session (2026-09-15)
- Step 3a: fonts (`Manrope[wght]`, `JetBrainsMono[wght]` + OFL, registered in
  `LicenseRegistry`), `lib/design/tokens.dart`, `theme.dart`,
  `focus/` (FocusableSurface, FocusPane, AppShortcuts, FocusRing), 13 basic
  components, and the keyboard-navigable gallery with live accent / density /
  reduce-motion switches
- Step 3b: `tools/extract_icons.dart` → `assets/icons/` (50 icons),
  `AppIcon` + `AppIcons`, 18 media and overlay components, and the gallery
  sections for them
- Two real bugs found by running the app and by the tests, both fixed:
  the focus ring drawn as a box shadow filled transparent ghost buttons
  (it strokes outside the control now), and `FocusPane` as a `FocusScope`
  trapped Tab inside a pane
- `docs/progress.md` updated, including the running ADR-008 list

## Instructions for the next session
1. Step 4 is written in `docs/plans/phase-1-foundation.md`. Stop for review
   when it is finished, as with every numbered step.
2. **The gallery is currently the app's home** (`lib/app/app.dart`). Step 4
   moves it to the `/dev/gallery` route and puts the shell in its place;
   `galleryEnabled` in `lib/design/gallery/gallery_availability.dart` already
   gates it to debug builds and `--dart-define=GALLERY=true`.
3. Build the shell out of the existing components — the nav rail, top bar,
   search field and casting-bar slot all have their pieces already. Read the
   canvas first (`design/*.dc.html`; `Main.dc.html` is the shell), not just
   docs/05: the canvas wins where they disagree.
4. `FocusPane` takes a `FocusPaneController`. Step 4's Left/Right between
   panes should use `controller.focusLast()`, falling back to the first item
   when it returns false.
5. The toast host in the shell is fed by `ErrorReporter` from step 2;
   `AppToast.defaultDuration` is the three seconds docs/05 asks for.
6. Icons: add to the `AppIcons` enum only what `tools/extract_icons.dart`
   produces. If the canvas gains an icon, re-run the tool and add its hash to
   `_names`; the tool fails loudly if a mapped icon disappears.
7. Commit messages carry no trailers. Commit locally; the user pushes.
8. At the end: analyze, format check, `flutter test`, update
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
- The canvas beats docs/05 on token values; docs/05 gets corrected at the end
  of the phase along with ADR-008.

## Open questions for the user
- The second Google TV doesn't answer on the network. Is it on another
  network, and should later casting tests include it?
- When the Windows PC is available for the Windows playback run.
- App name and icon (placeholder "IPTV Player").
- Light theme: tokens allow one, but it is out of scope for v1 (docs/05).
