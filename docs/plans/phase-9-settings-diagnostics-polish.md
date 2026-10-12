# Phase 9 — Settings, diagnostics, reminders and polish: plan

**Status: proposed 2026-10-12, for your approval.** What is built and every departure from this plan goes into ADR-016 (docs/decisions.md) as the steps land.

Three decisions are most worth your eye before you approve:
- **6:** what Export holds (your settings and your choices, never a password);
- **10:** a reminder shows only while the app is open, and nothing of it can be tried on Windows yet;
- **15:** the 8-hour soak needs your laptop for a night, with its screen on.

## Context
Phases 7 and 8 are built. What they lack is one sitting at your TV, about 35 minutes, when it is back on the network. Nothing in Phase 9 needs the TV or your provider's streams.

Phase 9 is the last phase before packaging. It finishes Settings, adds diagnostics and programme reminders, and then checks the whole app: by keyboard, at larger text, against every budget, and over eight hours.

Exit criteria (docs/08):
- Every budget in docs/06 is met in profile mode and recorded in docs/progress.md.
- The 8-hour soak with faults on Linux: no crash, memory growth ≤ 50 MB.
- Every screen passes the keyboard-only audit at 100, 115 and 130 % text scale, and with reduce motion.
- Copy diagnostics contains no credentials, checked with a real source configured.
- A reminder set from Search or the Guide shows a system notification at the programme's start on Linux, survives a restart, and opens the channel.

Already in place:
- **Settings:** the frame (the sub-navigation and the section card) and six sections: Sources, Playback, Casting, Downloads & library, Guide, Categories. Four are placeholders marked "Phase 9": Appearance, Keyboard shortcuts, Data, About & diagnostics.
- **Appearance's tokens:** accent, density and reduce motion can already change while the app runs. Only the Component Gallery changes them: the app itself always builds the default theme.
- **Logs:** one redacted log, 5 files of 5 MB, and `ErrorReporter` for failures nothing caught.
- **What diagnostics will read:** the player's `hwdec-current` (the stream info overlay shows it), the cast's encoder detection (remembered), each sync's and each guide import's counts with their skipped rows, the FFmpeg binaries found.
- **The system's settings reach the app:** Flutter's Linux embedder passes the desktop's text scale, its clock format and its animations switch. Your desktop has them at 100 %, 12-hour and on, so a "System" default changes nothing you see today.
- **Pieces a reminder needs:**
  - the Guide's programme sheet, and search opening the Guide on an upcoming programme;
  - `AppNotices` (toasts with an action);
  - four small D-Bus clients of our own (the portal, logind, NetworkManager, the file manager), each tested against a fake server inside the test;
  - the hook that runs after a guide import goes live.
- **Measurements that exist:** cold start, the Guide's and the poster grid's scroll, typing into search, the large sync, the guide import, the zap benchmark, the library and download benchmarks, and the soak tool with its 1-hour run.
- **The canvas** draws "Remind me" on Search's upcoming row, and the Settings frame. It draws none of the four missing sections: sketches A–I below.

What isn't there, found while reading the code for this plan:
- **No test runs at any text scale but 100 %.** About 150 places in the screens set a height from a token, so rows of text will overflow at 130 % until step 7 goes through them.
- **Compact density reaches only Live TV's channel rows.**
- **The clock is always 12-hour:** one function family, called from 24 places in 11 files.
- **Three budgets have no number from the app:** the channel list's scroll over 50,000 rows, idle memory with a guide, and H.264 1080p50's processor use (measured in Phase 0's spike only).
- **Two budgets are known misses:** the Guide's PageDown (22–28 frames over 16 ms per 20 presses) and the poster grid's fastest fling (13–17 of about 11,900 frames).

What Phase 9 does **not** own:
- **A light theme** (docs/05: after v1) and **rebinding shortcuts**.
- **Reminders while the app is closed:** that takes a helper that starts with the computer (decision 10).
- **Windows runs:** the notification, the GPU names and the text scale there are written, and CI builds them, but they wait for your PC.
- **The app's name and icon:** a notification shows both; "IPTV Player" and the placeholder until you choose (Phase 10 needs them).
- **Packaging** (Phase 10), and **the TV sitting** for Phases 7 and 8.

Carried in, not to be relitigated without new evidence:
- **Hard rules:**
  - **2:** reading 25 MB of logs, an export and an import run off the UI isolate;
  - **3:** nothing secret in the log viewer, the diagnostics, an export file or a notification;
  - **4 and 5:** every new page has its loading, empty, error and offline states and works by keyboard alone;
  - **6:** screens never import `dbus` or a notification package: reminders sit behind a port in `lib/core/`;
  - **9:** the text-scale rule lives in `lib/design/`, not in each screen.
- **ADR-013 decision 5:** a reminder is a system notification, not a toast: the window is often covered.
- **ADR-010:** the soak's memory is the median of the last five minutes over the median of minutes 21–25.
- **Your standing rules:** ask before any stream from your provider, and before any cast to the Living Room TV. This phase needs neither.

Working rhythm: one numbered step at a time, each ending with analyze, format, `TZ=UTC flutter test` and a local commit without trailers. I stop where a step needs you:
- before a real notification shows on your screen (step 5);
- before the profile runs take your display for a few minutes each (step 8);
- for the night of the soak (step 9).

## Decisions (my recommendation first in each)

1. **Start Phase 9 now, while the TV sitting waits.**
   - **Recommendation:** the same reasoning as Phase 8's decision 1. docs/08 says a phase starts once the one before has met its exit criteria; what Phases 7 and 8 lack is 35 minutes at a TV that is off the network. Nothing here touches casting, and both exits can still happen the day the TV is back.
   - **Rejected alternative: wait for the TV.** Nothing would move, and the sitting would be the same length.

2. **Appearance follows your desktop until you say otherwise.**
   - **Recommendation** (sketch A): five settings, applied at once and read before the first frame, so the app never opens in one look and changes to another.
     - **Accent:** docs/05's five colours.
     - **Text size:** System · 100 % · 115 % · 130 %. System follows the desktop's text size, up to 130 %.
     - **Density:** Comfortable · Compact. Compact shrinks the long lists: Live TV's channels and categories, the player's channel panel, Favorites' channels, the Categories manager, the Guide's rows. Posters, cards, dialogs and settings rows stay as they are.
     - **Reduce motion:** System · On · Off.
     - **Clock:** System · 12-hour · 24-hour.
   - **Why a text size of our own, when the desktop has one:** you can try 130 % without changing every other app, and the audit can be repeated by anyone.
   - **Why the cap at 130 %:** it is the largest size docs/05 promises and step 7 checks. A desktop set to 150 % gets 130 % here, which is bigger than today and laid out right, rather than 150 % with rows that overflow.
   - **Rejected alternative: only docs/05's four switches,** each defaulting to a fixed value. A desktop already set to large text or 24-hour time would have to be set again here.

3. **At larger text, a row that holds text grows with it. Pictures don't.**
   - **Recommendation:**
     - A height that holds text is multiplied by the text scale: rows, the top bar, buttons, chips, the Guide's rows. One helper in `lib/design/` does it, so no screen does its own sum.
     - Posters, logos, icons, the Guide's hour width and the nav rail's width keep their size. A poster card grows only by its text lines.
     - The minimum window (1024 × 640) must hold at 130 %. Where a row of buttons no longer fits, it wraps; it never clips.
     - **At 100 % nothing may move:** every existing golden must stay byte for byte the same. That is the check that the sweep changed only what it meant to.
   - **Rejected alternative: fixed rows, text cut with "…".** Two-line rows clip their second line at 130 %, which is exactly the user who asked for larger text reading less of it.

4. **Settings → Playback gets a hardware decoding switch: Automatic · Off.**
   - **Recommendation** (sketch E): Phase 3 left it out "until someone needs one". Diagnostics now shows what the decoder does, and Off is the only way round a faulty graphics driver without editing a file. Windows hardware has never run this app, so the first such driver may well be there. Off applies to the next thing played.
   - **Rejected alternative: leave it out.** A user whose picture is green or stuttering would have diagnostics that say why, and no way to act on it.

5. **Keyboard shortcuts is a list to read, and F1 shows it anywhere.**
   - **Recommendation** (sketch B):
     - Every shortcut, grouped by where it works, drawn with the keycaps the rest of the app uses.
     - **F1** opens the same list as a panel over whatever is on screen, the player included, and Esc closes it. Nothing stops playing.
     - The list is one table in the code. A test checks that every shortcut the app's global layer binds is in it.
   - **Rejected alternative: rebinding.** Nobody asked for it, and it is a second way to break hard rule 5 (two actions on one key).

6. **Export holds your settings and your choices; never a password, and it adds no source.**
   - **Recommendation** (sketch C):
     - **What goes in:**
       - the settings (appearance, playback, guide, casting, downloads);
       - per source: favorites and their groups and order; hidden, renamed and reordered categories; hidden and renamed channels; your guide matches;
       - your reminders.
     - **What never goes in:** passwords, usernames, playlist and guide addresses, watch history, the library's folders (paths differ between computers).
     - **How a source is recognized on import:** by its type, its server and a fingerprint of the username, not the username itself.
     - **Import shows what it will do first,** then applies it in one transaction: settings are replaced, and each source's choices are merged into the source already on this computer.
     - **A source in the file that isn't on this computer is named and skipped:** "Add it under Sources, then import again." Its password has to be typed here anyway.
     - **A file that is damaged, or from a newer version,** is refused with what is wrong; whatever in it is unknown is skipped, never fatal.
   - **Why choices and not only settings:** on your provider you picked from 146 live categories by hand. Doing that again on the Windows PC is the cost this feature is for.
   - **Rejected alternative: settings only.** It moves five pages of switches and leaves behind everything that took time.
   - **Rejected alternative: import creates the sources too.** A source without its password is a source that fails its first sync, and the address is half of a credential in a file that may be copied anywhere.

7. **There is no switch to turn channel-name cleanup off.**
   - **Recommendation:** Phase 6's plan mentioned such a switch for Appearance. I'd leave it out. Lists sort, filter and search by the cleaned name; a second naming mode doubles all three and their tests, for something Rename already fixes one channel at a time.
   - **Rejected alternative: build it.** Say so if cleanup still gets names wrong for you often enough to want it; it would be its own step.

8. **The log is read inside the app.**
   - **Recommendation** (sketch D):
     - The newest 2,000 lines at once, older ones as you scroll up, read off the UI isolate.
     - All · Warnings and errors, and a text filter.
     - It follows new lines while you are at the bottom, and holds still when you scroll up.
     - **Copy shown** and **Open log folder**.
     - Lines are redacted when they are written, so the viewer shows nothing the file doesn't.
   - **Rejected alternative: only "Open log folder".** Five files of 5 MB in a text editor, with no filter, is where a problem is hardest to find.

9. **Copy diagnostics shows you the text before it leaves, and leaves out who your provider is.**
   - **Recommendation** (sketch D):
     - **In it:**
       - the app's version and build, the system, the session (Wayland or X11) and the desktop;
       - the graphics cards and their drivers;
       - what decoded each kind of video last (H.264 1080p → `vaapi`), noted as things play;
       - the encoders found for casting, the FFmpeg and libmpv versions;
       - per source: its type, account status, connection limit, what it holds, its last sync and guide import with their skipped rows;
       - the settings that change behaviour;
       - the library's and the downloads' counts;
       - the last 50 warnings and errors.
     - **Never in it:** passwords, usernames, server addresses, the addresses of your devices. Your home folder is written `~`.
     - The whole text goes through `redact()` once more on its way out.
     - **Copy diagnostics** puts it on the clipboard; **Save to file…** writes it where you choose. The page shows the text itself, so you see what you are about to paste.
   - **The exit's check:** the test for hard rule 3 grows: a source whose server, username and password are strings found nowhere else, and none of the three in the report, the viewer or an export. Then the same search on the report made with your own source in the app. That signs in and reads your account; it opens no stream, and I'll say before I run it.
   - **Rejected alternative: include the server's address.** It helps nobody fix a decoder, and it names your provider in whatever public place the text gets pasted.

10. **A reminder is a system notification at the programme's start, while the app is open.**
    - **Recommendation** (sketch I):
      - **When the window is covered or minimized:** a system notification, "The Harbor Pilot · Starting now on Blue Water", with **Watch**. Clicking it or Watch brings the window forward and plays the channel full screen.
      - **When the window is in front:** a toast in the app with Watch instead. A notification on top of the app you are looking at is noise.
      - **Watch replaces what is playing,** as Enter on a channel does. While casting, it plays on the TV.
      - **Due while the app was closed, or the laptop asleep:** shown at the next launch or wake only while the programme is still on ("On now · … until 10:30 PM"); otherwise dropped without a word (docs/08).
      - A reminder is stored in the database (schema v10), so it survives a restart.
    - **The limit, plainly:** the app must be running. It doesn't have to be in front.
    - **Rejected alternative: a helper that starts with the computer** and notifies while the app is closed. It is a second program to install, start at login and supervise, and its notification would have to launch the app. Not for v1.

11. **Notifications: our own D-Bus client on Linux; the flutter_local_notifications package on Windows.**
    - **Recommendation:** both behind one port, `ReminderNotifier`, with "no notifications here" as a third answer that falls back to the toast.
      - **Linux:** `org.freedesktop.Notifications` through `dbus`, already a dependency. It is about 150 lines, like the four clients the app has, and it can be tested against a fake notification server inside the test: what is sent, the click, the Watch action, a desktop with no notification service.
      - **Windows:** `flutter_local_notifications` 22.3.1 (published in September 2026; Linux, Windows and four more; needs Flutter 3.38.1, we have 3.47.4). An app that isn't a store package needs only a name, an app id and a GUID. Without a package identity `cancel` does nothing, and we never cancel.
    - **Why not the package on Linux too:** its Linux side can't be pointed at a fake server, and bringing the window forward needs the token the desktop hands out with the click (below), which our own client can read.
    - **The one real unknown, tried first:** whether your desktop (GNOME 42 on Wayland) lets a notification's click bring the window to the front. Wayland refuses a window that raises itself; the notification spec has an `ActivationToken` for exactly this, and whether GNOME 42 sends it and GTK 3 accepts it is not something I could confirm by reading. Step 5 starts with a half-hour spike. If the window can't be raised, the channel still plays and GNOME says "IPTV Player is ready" — recorded, not hidden.
    - **Rejected alternative: local_notifier.** Its last release is two years old.

12. **A reminder follows its programme through a guide refresh.**
    - **Recommendation:** after an import goes live, each reminder looks for its programme on the same guide channel with the same title.
      - **Found at another time, within 12 hours:** the reminder moves. A move of 5 minutes or more says so: "The Harbor Pilot moved to 9:45 PM. Your reminder moved with it."
      - **Not found, in a guide that covers that time:** the reminder is removed and says so once.
      - **A guide that doesn't reach that time** (a failed refresh, a guide that ran out): the reminder stays. A guide that is missing isn't a programme that was cancelled.
      - A source that is removed takes its reminders with it.
    - **Rejected alternative: keep the stored time whatever the guide says.** A match moved by an hour would remind you an hour early, of nothing.

13. **Where a reminder is set, and the one place they are managed.**
    - **Recommendation** (sketches F, G, H):
      - **Search:** an upcoming row says **Remind me** at its right, as the canvas draws it, and "Reminder set" with a bell once it is. The mouse clicks it; the keyboard stays in the field, so **Ctrl+R** toggles it (as Ctrl+D downloads) and the menu key has it. Enter still opens the Guide on the programme.
      - **The Guide's sheet:** **Remind me** after Watch channel, on a programme that hasn't started; it becomes "Reminder set · Remove".
      - **The Guide's grid:** **R** on the focused programme, and a small bell in a cell that has one.
      - **Reminders,** a dialog listing them soonest first, each with Remove; Enter opens the Guide on it. Two doors to the one list: a bell with the count in the Guide's toolbar, and a row in Settings → Guide.
      - Setting one says "Reminder set · Tomorrow, 9:30 PM" with Undo.
    - **Rejected alternative: a Reminders section of its own in Settings.** Reminders are found and set in the Guide; a list four clicks from there wouldn't be found.

14. **The audit is a test matrix that stays, not a read-through done once.**
    - **Recommendation:**
      - **One harness** pumps every screen in every state it has (loading, empty, error, offline, content) at 100, 115 and 130 %, at the minimum window and at 1920 × 1080, with reduce motion on and off. It fails on:
        - anything that overflows or is clipped;
        - a control Tab and the arrows can't reach;
        - a focus stop that paints no ring;
        - a Tab walk that doesn't come back round (a trap);
        - with reduce motion, an animation longer than 80 ms or a shimmer.
      - **Goldens at 130 %** for the screens with the most text, each one looked at.
      - **The keyboard walks that exist** (sources, Live TV, the Guide, search, favorites, the library, casting) run once more at 130 %.
      - **The screen-by-state table** goes into ADR-016: which state each screen has, and what was found and fixed.
      - **The loose ends already known are in scope:**
        - Tab on a two-column details page passes Play;
        - the provider's Series page swaps its season when a mark moves Continue;
        - Live TV's categories pane forgets the chosen category when Tab comes round;
        - the Guide's "Offline" reads its last failure, not the network status the app has had since Phase 8;
        - a subtitle the TV refuses says nothing;
        - Favorites' drag draws Flutter's gap, not the canvas's accent line.
    - **Rejected alternative: check by hand, fix, move on.** The next change to a row's height would break 130 % again with nothing to say so.

15. **The soak plays the app as it is used now, and runs for a night you choose.**
    - **Recommendation:**
      - **What it does:** docs/06's soak is live playback with zaps and faults. Since Phase 3 the app gained a relay isolate, a downloads isolate, a picture cache and a guide. So about every 20 minutes the soak also casts to the fake TV for two minutes, runs a download from the fake panel, and walks the Guide, Movies and Search. The pass rule doesn't change: every fault recovered, no crash, growth ≤ 50 MB.
      - **A 1-hour run of the new mix comes first,** to find the soak's own mistakes before a night is spent on them.
      - **The night:** the laptop plugged in, lid open, the app's window on the real display, muted, with the desktop kept from locking for the run (a locked Wayland session stops drawing, which changes what is measured). About 8 hours 10 minutes. Only the fake panel and the fake TV: nothing from your provider, nothing on your TV. I start it when you say, and read it the next session.
    - **Rejected alternative: live playback only.** It could pass while a relay or a picture leak went unseen, and "8 hours with no leak" would be true of a third of the app.

16. **Profile-mode numbers where a frame or a launch is measured; the benchmarks as they are for the rest.**
    - **Recommendation:**
      - **In the profile build on your display:** cold start, the three scrolls (channel list, Guide, poster grid), typing into search, the sync's frames, idle memory, H.264 1080p50's processor use, and the zap.
      - **As `flutter test` benchmarks:** the sync's and the import's times, search per query, the library's scans, the downloads. They run as debug code, which is slower than profile, so a pass there is a pass.
      - **The two known misses get fixed, not re-budgeted.** If one won't close after an honest try, I stop and show you the numbers; I don't move the line.
    - **Rejected alternative: everything through `flutter drive --profile`.** It would mean rewriting six benchmarks to learn that faster code is faster.

## Step 1 — Appearance, and what it rests on
- **`AppearanceSettings`:** accent, text size, density, reduce motion, clock. One JSON value in the settings table, as Playback's is, read by `bootstrap()` before `runApp`. A damaged value reads as the defaults.
- **The app builds its theme from it.** A wrapper above the router sets the text scale (the system's or the chosen one, capped) and tells the tokens whether to reduce motion.
- **The clock:** `formatClock` and its family take a `TimeStyle`. Screens get it from the tokens; text made off screen (toasts, a notification) from a provider. No global.
- **The text helper** in `lib/design/` (decision 3), and the design system's own components moved onto it. Screens follow in step 7.
- **Density** reaches the long lists (decision 2).
- **Settings → Appearance** (sketch A): every control by keyboard, each change shown at once; "Couldn't read your settings" with Retry.
- **Verify:**
  - unit: the JSON round trip, damaged values, the cap, System resolving to the desktop's value;
  - widget: each control, a restart keeps the choice, the first frame already has it;
  - goldens: the page; the component sheets at 130 %, in Compact and in one other accent, each looked at;
  - **every existing golden unchanged.**

## Step 2 — Keyboard shortcuts, hardware decoding, About
- **The shortcut table** in code, the page (sketch B) and the **F1** panel over any screen.
- **Hardware decoding** (decision 4, sketch E): `PlaybackSettings` gains it; the engine opens with `hwdec=auto-safe` or `no`.
- **About:** the name, version and build (from the build's own version file; no new package unless that fails on Windows), and **Licences**: the packages' and the bundled fonts', FFmpeg's and libmpv's.
- **Verify:**
  - the test that every global shortcut is in the table;
  - widget: the page and the panel by keyboard, F1 over the player leaves it playing;
  - the engine's options for both choices (the fake engine), and one real play with Off under Xvfb (`player_engine_test`);
  - docs/05's shortcut table and the page say the same.

## Step 3 — Data
- **Pictures:** "412 MB of 500 MB" and **Clear**, which asks first, then empties the disk cache and the decoded pictures off the UI isolate.
- **Guide:** "142,880 programmes until Oct 19" and **Clear guide**, which asks first. Programmes go for every source; your matches stay; the next refresh brings the guide back.
- **Export… / Import…** (decision 6, sketch C): format 1, written and read off the UI isolate; the preview; one transaction; a summary toast.
- **Verify:**
  - fixtures for the reader: a good file, a truncated one, one that isn't JSON, a newer format, unknown keys, a source that isn't here;
  - end to end on two databases: export from one, import into a fresh one with the same fake source — settings, favorites with groups and order, hidden and renamed channels and categories, matches and reminders all arrive;
  - **an import that fails part-way changes nothing;**
  - hard rule 3: no password, username or address in the file;
  - widget: every state of the page and both dialogs, by keyboard.

## Step 4 — Diagnostics
- **What decoded what:** the playback coordinator notes `hwdec-current` per codec and size as things play (the last 20, in the settings table).
- **The system's facts** behind a port: Linux reads `/etc/os-release`, the session's variables and `/sys/class/drm`; Windows asks the system through win32, untried.
- **The report** (decision 9), **Copy diagnostics**, **Save to file…**, and the preview.
- **The log viewer** (decision 8).
- **Verify:**
  - the hard-rule-3 test grown to the report, the viewer and the export;
  - the report built on a database with a failed sync, a skipped-row count and no source at all;
  - the viewer on 25 MB of generated log: first lines within 100 ms, no UI pause over 16 ms (a benchmark), the filter, following the tail;
  - widget: every state, by keyboard;
  - **with your go-ahead:** the report made with your own source configured, searched for its server, username and password.

## Step 5 — Reminders: the store, the scheduler, the notification
- **The spike first** (decision 11): a throwaway script shows a notification on your desktop and tries to bring a window forward on its click, under Wayland and under X11. **I'll say before it shows.** What it finds goes into ADR-016.
- **Schema v10:** `reminders` (the source, the channel, the guide channel, the title, start and end, when it was set), cascading from `sources`; the migration test.
- **The domain:** `Reminder`, `ReminderRepository`, and `ReminderScheduler` — plain rules over a clock:
  - one timer to the next due reminder, looked at again every minute, so a sleep or a changed clock is caught;
  - what is due, what is late but still on, what is over;
  - decision 12's follow, run after each import goes live.
- **`ReminderNotifier`:** the Linux client, the Windows one, and none.
- **Bringing the window forward,** with the desktop's token when there is one.
- **Verify:**
  - the scheduler under fake time: on time, late and still on, late and over, a sleep across the start, the clock set back, two at the same minute;
  - the follow: moved, moved by under 5 minutes, removed, a guide that doesn't reach it, a source removed;
  - the Linux client against a fake notification server: what is sent, a click, Watch, closed unread, no service at all;
  - no credential in anything sent (the hard-rule-3 test);
  - CI builds the Windows side.

## Step 6 — Reminders on screen
- **Search, the Guide's sheet, the Guide's grid, the Reminders dialog and its two doors** (decision 13, sketches F–H), and the toasts (sketch I).
- **Watch:** the window forward, the channel full screen; while casting, on the TV.
- **Verify:**
  - widget: each place and each state by keyboard — nothing upcoming, a reminder set, removed, undone, a programme that started meanwhile, the list empty and full, a guide that can't be read;
  - **`integration_test/reminder_walk_test.dart`**, keys only, on the fake panel's guide with the app's clock in the test's hand: search → Ctrl+R → the Guide shows the bell → the app closed and opened again → the reminder is there → the clock reaches the start → the notification (a recording notifier) → Watch → the channel plays;
  - **on your desktop, with you there:** one real reminder, a minute ahead, from the app itself.

## Step 7 — The audit
- **The harness** (decision 14) and the table of screens by state.
- **The sweep:** every screen's heights onto the text helper; every finding fixed, each with the harness as its test.
- **The known loose ends** (decision 14's list).
- **Offline:** every screen that needs the network says so from the app's network status, not from its last failure.
- **Verify:**
  - the harness green for every screen and state at the three sizes, both windows, reduce motion both ways;
  - the 130 % goldens, each looked at;
  - the keyboard walks at 130 % under Xvfb, one file per run;
  - every golden at 100 % unchanged.

## Step 8 — Performance, in profile mode
- **New measurements:**
  - `integration_test/channel_list_scroll_test.dart` (50,000 rows: flings, the wheel, ↓, PageDown, End);
  - idle memory, ten minutes after a launch with the `large` catalogue and a 600,000-programme guide;
  - H.264 1080p50's processor use in the app's own player.
- **The two misses:** the Guide's PageDown and the poster grid's fastest fling, measured with the timeline first, then fixed.
- **Every row of docs/06's table** run again and written into docs/progress.md with its date, as decision 16 divides them.
- **Before each run on your display I say so;** each takes a few minutes and the window must stay in front.
- **Verify:** the table itself, every row within its budget, three runs where a number wanders.

## Step 9 — The soak, and the exit
- **The soak's new mix** (decision 15), its 1-hour run, then **the night**, when you say.
- **Whatever it finds, fixed,** and the hour or the night run again as the fix needs.
- **Docs:**
  - ADR-016 Accepted, ADR-002 gains the notification package;
  - docs/05 "As built" for the four sections, reminders and the text-scale rule;
  - docs/06: the audit harness, the new measurements, the soak as it now runs;
  - docs/02: schema v10;
  - progress and the handoff.

**Alongside, one small commit each:** whatever CI names after your next push.

## Sketches for approval (not on the canvas)

**A. Settings → Appearance:**
```
Appearance                                              Changes show at once.

Accent          ( ● Blue   ● Violet   ● Teal   ● Amber   ● Rose )
Text size       ( System | 100 % | 115 % | 130 % )
                System follows your desktop's text size, up to 130 %.
Density         ( Comfortable | Compact )
                Compact fits more rows in the long lists.
Reduce motion   ( System | On | Off )
                No zoom or shimmer, and nothing moves for longer than a blink.
Clock           ( System | 12-hour | 24-hour )                      8:05 PM
```

**B. Settings → Keyboard shortcuts, and the F1 panel** (the same list):
```
Keyboard shortcuts                                   F1 shows this list anywhere.

ANYWHERE
  Search                              [Ctrl] [K]   or   [/]
  Home … Library                      [Ctrl] [1]  …  [Ctrl] [7]
  Settings                            [Ctrl] [,]
  The focused item's menu             [Menu]   or   [Shift] [F10]
LIVE TV AND THE PLAYER
  Previous / next channel             [↑] [↓]   or   [PageUp] [PageDown]
  Last channel                        [Backspace]
  …
THE GUIDE · MOVIES AND EPISODES · SEARCH · CASTING · DOWNLOADS AND THE LIBRARY
```

**C. Settings → Data, and Import's preview:**
```
Data
PICTURES    Posters, logos and stills kept on this computer.
            412 MB of 500 MB                                         [ Clear ]
GUIDE       142,880 programmes until Oct 19.                   [ Clear guide ]
            Your channel matches are kept. The guide comes back at its next refresh.
YOUR SETTINGS AND CHOICES
            Settings, favorites and groups, hidden and renamed channels and
            categories, guide matches and reminders. Never passwords.
                                                   [ Export… ]   [ Import… ]

Import "iptv-player-settings-2026-10-12.json"?
  Settings        replaced with the file's
  Northwind TV    212 favorites · 3 groups · 41 hidden categories · 9 guide matches
  Harbor IPTV     not on this computer — add it under Sources, then import again
                                                       [ Cancel ]   [ Import ]
```
Cancel has the focus. Clear and Clear guide ask first, with Keep focused.

**D. Settings → About & diagnostics:**
```
About & diagnostics
IPTV Player 0.1.0 (build 1) · Linux                               [ Licences ]

DIAGNOSTICS   What the app, the player and the converter found on this computer.
              No passwords, usernames or server addresses.
                                       [ Copy diagnostics ]   [ Save to file… ]
  ┌──────────────────────────────────────────────────────────────────────────┐
  │ IPTV Player 0.1.0+1 · Ubuntu 22.04 · Wayland · GNOME                      │
  │ Graphics: Intel UHD 630 (i915) · NVIDIA GTX 1650 Ti (nvidia)              │
  │ Decoding: H.264 1080p → vaapi · HEVC 2160p → vaapi                        │
  │ Casting encoders: h264_nvenc · h264_vaapi · libx264                       │
  │ Source 1: Xtream · Active · 1 connection · 12,610 channels · 20,072 …     │
  │   last sync 2 h ago, 8.7 s, 0 rows skipped                                │
  │ Recent warnings and errors (50) …                                         │
  └──────────────────────────────────────────────────────────────────────────┘

LOG                               ( All | Warnings and errors )   [ Filter… ]
  20:14:03.412  INFO   playback   Opening channel 147
  20:14:07.530  WARN   watchdog   Stalled for 4 s, reconnecting (1 of 6)
  …                                         [ Copy shown ]   [ Open log folder ]
```
The preview and the log are each one Tab stop, with the arrows, PageUp/PageDown and Home/End inside.

**E. Settings → Playback, the new row:**
```
Hardware decoding   ( Automatic | Off )
                    Automatic uses your graphics card when it can. Off decodes on the
                    processor: slower, and a way round a faulty graphics driver.
                    Applies to the next thing you play.
```

**F. Search's upcoming rows** (the canvas draws the first):
```
ON TV NOW & UPCOMING
 [CS]  Harbor Kings vs Ridge City     Courtside · ends 10:55 PM            ● LIVE
 [BW]  The Harbor Pilot               Blue Water · Tomorrow, 9:30 PM    Remind me
 [BW]  The Harbor Pilot               Blue Water · Tomorrow, 9:30 PM  🔔 Reminder set
```

**G. The Guide's sheet and a cell:**
```
The Harbor Pilot
Tomorrow · 9:30 – 10:30 PM · Drama
Blue Water · 212
A pilot boat crew takes the night shift …
[ Watch channel ]   [ 🔔 Remind me ]   [ ☆ Add to favorites ]
[ Watch channel ]   [ 🔔 Reminder set · Remove ]   [ ☆ Add to favorites ]

│ 9:30 PM  The Harbor Pilot  🔔 │
```

**H. Reminders** (the Guide's toolbar: `🔔 3`; Settings → Guide: "Reminders · 3   [ Manage ]"):
```
Reminders · 3
 [BW]  The Harbor Pilot     Blue Water     Tomorrow, 9:30 PM      [ Remove ]
 [CS]  Late Scores          Courtside      Fri 16, 11:00 PM       [ Remove ]
 [HW]  Coastal Forecast     Harborview     Sat 17, 7:00 AM        [ Remove ]
 A reminder shows when its programme starts, while the app is open.
                                                                   [ Close ]

No reminders
Press R on an upcoming programme in the Guide, or choose Remind me in Search.
```
The list is one Tab stop: ↑/↓ between rows, Enter opens the Guide on the programme, Delete removes with Undo.

**I. What a reminder says:**
```
The system's notification      IPTV Player
(the window covered)           The Harbor Pilot
                               Starting now on Blue Water                [ Watch ]

In the app (the window in front)   Starting now · The Harbor Pilot on Blue Water   [ Watch ]
At a launch, still on              On now · The Harbor Pilot on Blue Water, until 10:30 PM   [ Watch ]
After a guide refresh              The Harbor Pilot moved to 9:45 PM. Your reminder moved with it.
                                   The Harbor Pilot is no longer in the guide. Its reminder was removed.
Setting one                        Reminder set · Tomorrow, 9:30 PM   [ Undo ]
```

## Verification (every step and at the exit)
The same set every step:
- `flutter analyze`;
- `dart format --set-exit-if-changed lib test integration_test tools`;
- `TZ=UTC flutter test` (unit, widget, golden);
- the fake panel's and the fake TV's own suites;
- the integration tests the step touches, one file per run under `xvfb-run -a`.

What the tests must cover:
- **Nothing secret leaves the app:** one test puts a source's server, username and password, as strings found nowhere else, through the log viewer, the diagnostics report, an export file and a notification, and finds none of them.
- **A reminder never fires twice, and never for a programme that is over,** shown under fake time.
- **An import either applies whole or not at all.**
- **At 100 % nothing moved:** the existing goldens, byte for byte.
- **Every screen and state at three text sizes,** by the harness, from step 7 on in every run.
- Every new page gets widget tests for each state; timings and memory are measured, not assumed.

## Risks
- **GNOME may not let a click bring the window forward.** The spike says before anything is built on it; the fallback (the channel plays, GNOME says the app is ready) is honest and recorded.
- **Other desktops differ:** KDE's notifications, a window manager with no notification service at all. The port's third answer (the toast) covers the last; the others are untried.
- **Windows can't be tried here:** the notification, which needs the app id the Phase 10 installer registers; the graphics cards' names; the system's text scale. If the Windows build refuses the notification package, the step says so and Windows keeps the toast until your PC.
- **A laptop asleep at a programme's start shows nothing until it wakes.** Then the launch rule applies: shown only while still on.
- **The text-scale sweep touches about 150 heights.** The 100 % goldens are the guard; a height missed shows up in the harness, not in your hands.
- **The two frame misses may not close.** Then I stop with the numbers and ask (decision 16).
- **The soak may find a leak that isn't ours** (libmpv, the graphics driver). Then the choice is yours, with the numbers: a way round it, or a recorded limit.
- **The soak takes your laptop for a night,** with the screen lit and the desktop unlocked. A run you interrupt just has to run again.
- **Size:** docs/08 says 1–1.5 weeks. The steps are ordered so the audit and the measurements come after everything they must cover is built.
