# Installing Bijou, and keeping the code safe

The stable version is always `main` (ADR-034): only tested work is merged
there, and each merge is tagged `stable-<build>`. `dev` is where new work
happens first.

## Keep the code on GitHub

After every session (or whenever there are new commits):

```
git push origin --all && git push origin --tags
```

`--all` sends every branch (`main`, `dev`, and any work-in-progress
branch), `--tags` every tag (the `stable-…` builds and the checkpoints).
Nothing is ever lost locally that way, and GitHub's CI checks `main` on
each push. Pushing the same thing twice is harmless.

The repository is public: anything pushed, the cover photo in
`design/brand/` and the icons made from it included, can be seen by
anyone.

## Linux (this PC)

```
tools/install_stable_linux.sh
```

This builds `main` as a release in its own folder (your `dev` checkout is
left alone), installs it to `~/.local/share/bijou/app`, and adds Bijou to
the app grid with its icon. Open it from the app grid or the dock. Run
the same command again to update after a new stable build; give it a tag
to install that one instead (`tools/install_stable_linux.sh stable-287`).
`tools/install_stable_linux.sh --remove` takes it away.

- The first build takes a few minutes; later ones reuse
  `~/.cache/bijou/stable-src`.
- It needs what development needs (docs/setup.md): Flutter, the Linux
  build tools and `libmpv`. Casting needs the bundled FFmpeg
  (`tools/fetch_ffmpeg.sh`, already done on this PC).
- Your data (sources, favorites, history, settings) is in
  `~/.local/share/io.github.yasiralobaidi.iptvplayer`. The installed
  app and anything run from the checkout (`flutter run`) share it.

**Another Linux PC, without Flutter:** until the AppImage (Phase 10),
download the `iptv-player-linux-x64` artifact of the latest green CI run
on `main` (GitHub → Actions → the run → Artifacts; you must be signed in,
and artifacts are kept 90 days), unzip it anywhere, install the player
library (`sudo apt install libmpv1` on Ubuntu 22.04, `libmpv2` on 24.04)
and run `iptv_player`. That build can't cast (no FFmpeg in it).

## Windows

**Quickest (no tools needed):** on GitHub, open Actions, the latest run
on `main` whose Windows job is green, and download the
`iptv-player-windows-x64` artifact (signed in; kept 90 days). Unzip it to
`%LOCALAPPDATA%\Programs\Bijou`, run `iptv_player.exe`, and pin it to
Start or the taskbar. Windows SmartScreen warns about an unknown app the
first time (the build isn't signed): *More info → Run anyway*. This build
plays everything but can't cast (no FFmpeg in it). To update, replace the
folder's contents with a newer artifact; your data stays in
`%APPDATA%\io.github.yasiralobaidi\IPTV Player`.

**Complete (with casting), built on the Windows PC:** install Git for
Windows, Flutter (stable) and Visual Studio 2022 with *Desktop
development with C++* (docs/setup.md, section 5). Then, in Git Bash:

```
git clone https://github.com/yasir-alobaidi/iptv-player.git
cd iptv-player
git checkout main
tools/fetch_ffmpeg.sh windows-x64
flutter build windows --release
```

Copy `build\windows\x64\runner\Release` to
`%LOCALAPPDATA%\Programs\Bijou` and run `iptv_player.exe` from there. To
update: `git pull`, build again, copy again.

A proper installer (MSIX or Inno Setup) is Phase 10's work
(docs/08-phases-and-prompts.md).

## Google TV

`tools/tv_apk.sh stable` builds the stable "Bijou" from `main` into
`build/tv/` (`tools/tv_apk.sh beta` builds "Bijou Beta" from `dev`); the
session installs it over adb (docs/07-google-tv.md).

## Other platforms

- **Mac:** possible, not built yet. Flutter, the player (media_kit /
  libmpv), the secure storage and the window code all run on macOS. It
  needs a Mac with Xcode to build and test on, FFmpeg builds for macOS for
  casting, and either an Apple developer account (about $99 a year) to
  sign it or a one-time "Open anyway" in System Settings. Roughly a
  phase of work, mostly packaging and testing.
- **Android phones and tablets:** the closest of all: the TV app is
  already an Android app, so the APK installs on a phone today, but its
  screens are made for a remote and a 16:9 screen. A phone version needs
  touch-first layouts (portrait, bottom navigation, gestures in the
  player). A phase of work, like the TV's.
- **iPhone and iPad:** the most work. It needs the touch layouts above,
  a Mac with Xcode, and an Apple developer account to install it for
  more than 7 days at a time (or App Store review). iOS doesn't let an
  app run FFmpeg as its own program, so casting would have to be
  rebuilt on an FFmpeg library; playback, downloads and the rest carry
  over.
