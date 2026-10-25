# Windows: the first run on a real PC

Bijou has never run on a real Windows PC. CI builds the Windows app on
every push to `main` and runs all the unit and widget tests there
(goldens excluded), so the code compiles and its logic holds on Windows.
CI does **not** show a picture on a real graphics card, run the app's
integration walks, cast, or install anything. This list covers what
only a real PC can show. About an hour, once; then again only when
something Windows-specific changes.

What's needed: a Windows 10 or 11 PC (a laptop is fine; a virtual
machine can do items 1–4 and 9 only, with no graphics card for the
picture), on the same Wi-Fi as a Chromecast or Google TV for casting,
and the provider free for a few minutes (one connection).

Write the result of each line next to it (OK, or what happened), and
attach `%APPDATA%\io.github.yasiralobaidi\IPTV Player\logs\app.log`.

## Install
1. Download `Bijou-Setup.exe` from the latest release
   (docs/install/windows.md). SmartScreen's "Windows protected your PC":
   More info → Run anyway. The UAC prompt: Yes.
2. Setup finishes with "Launch Bijou" ticked: the app opens, its icon on
   the taskbar, the Start menu entry and the desktop shortcut are there.
3. Run the same setup again over it: it updates in place, no second
   entry in Settings → Apps.

## The app
4. Onboarding: add the provider (or the fake panel:
   `dart run tools/fake_provider/bin/server.dart --port 8899 --host 0.0.0.0`
   on the Linux laptop, then `http://<laptop's address>:8899`, test/test).
   The first sync finishes; Home, Live TV, Movies, Series fill in.
5. Close and reopen: still signed in (the password is in Windows'
   Credential Manager), the window where it was.

## The picture (needs the provider or the fake panel)
6. A channel plays with sound. Stream info (I): the decoder is
   `d3d11va` (hardware), not `no`. Note the CPU in Task Manager.
7. A film plays; seek ±10 s, pause for 10 s and resume: the sound and
   the picture together (ADR-054). Full screen and back.
8. Settings → Playback → Picture quality is High; the log has no
   "Standard for this title" line for a 1080p film (ADR-055). Then
   Hardware decoding Off: the same channel still plays (on the
   processor).

## Casting and the rest
9. The firewall: no "Windows Defender Firewall has blocked" prompt when
   casting starts (the setup added the rule). If the network is
   "Public" in Windows, cast discovery may find nothing: set it to
   Private (Settings → Network & internet → Wi-Fi → the network).
10. Cast a channel and a film to the TV: they play, the bar is right,
    Stop on the PC stops the TV. Task Manager shows `ffmpeg.exe` only
    while a cast needs it, and none after Bijou closes.
11. A download of one episode: it finishes, opens from Library, and
    "Show in folder" opens Explorer at the file (Arabic names too).
12. A programme reminder: the Windows notification appears at its time.
13. Settings → Apps → Bijou → Uninstall: the app goes; reinstalling
    finds the sources and history still there (the data in `%APPDATA%`
    stays, as the guide says).
