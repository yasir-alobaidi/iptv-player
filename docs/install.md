# Installing Bijou, releasing it, and keeping the code safe

**To install Bijou** (for anyone, no GitHub account needed):

- [Windows](install/windows.md): download and open `Bijou-Setup.exe`.
- [Linux](install/linux.md) (Ubuntu 22.04 or newer and its family, Debian
  13): one line in the Terminal.
- [Google TV, Android TV, Fire TV](install/android-tv.md): the Downloader
  app and one address.

Their links never change: `https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/<file>`
always gives the newest release's file. The rest of this page is for
whoever makes the releases.

The stable version is always `main` (ADR-034): only tested work is merged
there, and each merge is tagged `stable-<build>`. `dev` is where new work
happens first.

## The files to hand out: `dist/`

The installers live in the project's **`dist/`** folder (git ignores it),
ready to copy to a USB stick or another computer:

- **`dist/Bijou-TV.apk`**: the TV app, "Bijou" with the blue jewel, 32-
  and 64-bit, signed with the TVs' key. Made here, from the checkout (on
  `main` for the stable one): `tools/dist_apk.sh` (about 3 minutes).
  `tools/dist_apk.sh cover` makes `dist/Bijou-TV-cover.apk` with the
  cover photo instead (FAISAL TV's look; its label is changed by hand).
  To hand it to a TV on this Wi-Fi: `python3 tools/serve_apk.py`, then
  the address it shows in the TV's Downloader
  ([the TV guide](install/android-tv.md#from-a-computer-over-wi-fi-the-fastest)).
- **`dist/Bijou-Setup.exe`**: the Windows installer. A Windows app can
  only be built on Windows, so GitHub builds it (the release, below);
  `tools/fetch_release.sh` downloads the latest release's
  `Bijou-Setup.exe` and `Bijou-TV.apk` into `dist/` (`all` for the Linux
  files too, and a tag for an older release).
- The Linux installer needs no file: one line (the Linux guide).

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

## How a release is made

1. Merge the tested work into `main` and tag it `stable-<build>`, the
   build being `main`'s commit count (`git rev-list --count main`), as
   before.
2. Push (above). The tag starts the **Release** workflow
   (`.github/workflows/release.yml`; GitHub → Actions → Release), which
   takes about 30–45 minutes:
   - **Linux**, twice: on Ubuntu 22.04 (libmpv.so.1) and 24.04
     (libmpv.so.2), since the app links the system's libmpv and one build
     can't serve both. Each fetches FFmpeg (casting) and builds libva,
     builds the release, and packs it with `tools/package_linux.sh` as
     `bijou-linux-x64-ubuntu22.04.tar.gz` / `…24.04.tar.gz` (its log
     lists what the bundle links from the system).
   - **Windows:** FFmpeg, the release build, the MSVC runtime DLLs beside
     `iptv_player.exe` (a fresh Windows has no Visual C++ runtime), and
     `Bijou-Setup.exe` from `windows/packaging/bijou.iss` (Inno Setup).
   - **Google TV:** `Bijou-TV.apk`, 32- and 64-bit ARM (the Chromecast
     with Google TV, other TVs, Fire TV), signed with the key from the
     repository's secrets (below). The job fails if the secrets are
     missing or the APK's certificate isn't the TVs' one.
   - **Publish:** the GitHub Release `stable-<build>`, titled
     "Bijou <build>", with those files, `install-linux.sh`
     (`tools/install_linux.sh`) and `SHA256SUMS.txt`, and short notes
     with the three install links. It becomes the **Latest** release, so
     the links above now give it.
3. Check the release page, then install it as the guides say (that's
   also the test of the guides).

The build number is the commit count, so every job checks out the whole
history: the TV refuses an APK whose version code is lower than the one
installed, and a shallow clone would count 1.

**By hand:** Actions → Release → **Run workflow**, with the tag. Use it to
re-run a release (the files are replaced) or when the tag push didn't
start it: GitHub sends no event when **more than three tags are pushed at
once**. It works for tags made after `release.yml` existed (older tags
don't have the scripts). Rebuilding an older tag doesn't make it Latest.

## One-time setup: the TV app's signing key

Android installs an update only over an app signed with the same key. The
Bijou on both TVs was signed with this laptop's debug key
(`~/.android/debug.keystore`, alias `androiddebugkey`, passwords
`android`), so the release signs with that key too, and the downloaded
APK updates them in place, sign-in kept. A different key would mean
uninstalling Bijou from every TV first.

1. On this laptop: `base64 -w0 ~/.android/debug.keystore` and copy the
   one long line it prints.
2. GitHub → the repository → **Settings** → **Secrets and variables** →
   **Actions** → **New repository secret**, four times:

   | Name | Secret |
   |---|---|
   | `BIJOU_KEYSTORE_BASE64` | the line from step 1 |
   | `BIJOU_KEYSTORE_PASSWORD` | `android` |
   | `BIJOU_KEY_ALIAS` | `androiddebugkey` |
   | `BIJOU_KEY_PASSWORD` | `android` |

That's all. Secrets are readable only by workflows in this repository
(not by pull requests from forks) and are masked in logs. The workflow
writes the key to a temporary file on the runner and deletes it after
the build; `android/app/build.gradle.kts` signs with it when
`BIJOU_KEYSTORE` names a keystore, and with the debug key otherwise
(local builds and `tools/tv_apk.sh`, which give the same certificate on
this laptop).

- **Keep a copy of `~/.android/debug.keystore`** somewhere safe (not in
  the repository). If it's lost, no future Bijou can update the TVs'
  without uninstalling it first.
- The workflow checks the APK's certificate against the TVs'
  (`EXPECTED_CERT_SHA256` in `release.yml`, SHA-256 `882fd9bd…7e8f`): a
  wrong secret fails the job. Change that value only together with the
  key.

## Building it yourself

**Linux, on this PC, from `main` (or any tag):**

```
tools/install_stable_linux.sh
```

This builds `main` as a release in its own folder (your `dev` checkout is
left alone), installs it to `~/.local/share/bijou/app`, and adds Bijou to
the app grid with its icon: the same place and entry as the release
installer, so either one updates the other. Run it again to update; give
it a tag to install that one instead (`tools/install_stable_linux.sh
stable-287`). `tools/install_stable_linux.sh --remove` takes it away.

- The first build takes a few minutes; later ones reuse
  `~/.cache/bijou/stable-src`.
- It needs what development needs (docs/setup.md): Flutter, the Linux
  build tools and `libmpv`. Casting needs the bundled FFmpeg
  (`tools/fetch_ffmpeg.sh`, already done on this PC).
- Your data (sources, favorites, history, settings) is in
  `~/.local/share/io.github.yasiralobaidi.iptvplayer`. The installed
  app and anything run from the checkout (`flutter run`) share it.

**A Linux tarball, as the release makes it:** `flutter build linux
--release`, then `tools/package_linux.sh
dist/bijou-linux-x64-ubuntu22.04.tar.gz` and
`tools/install_linux.sh --from dist/bijou-linux-x64-ubuntu22.04.tar.gz`
(add `--skip-packages` to leave apt alone).

**Windows, on a Windows PC:** Git for Windows, Flutter (stable), Visual
Studio 2022 with *Desktop development with C++* (docs/setup.md, section
5) and Inno Setup 6. In Git Bash:

```
git clone https://github.com/yasir-alobaidi/iptv-player.git
cd iptv-player
git checkout main
tools/fetch_ffmpeg.sh windows-x64
flutter build windows --release
"/c/Program Files (x86)/Inno Setup 6/ISCC.exe" windows/packaging/bijou.iss
```

That gives `build\windows\installer\Bijou-Setup.exe` (copy
`msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` into
`build\windows\x64\runner\Release` first if it's for a PC without the
Visual C++ runtime, as the workflow does).

**Google TV:** `tools/tv_apk.sh stable` builds the stable "Bijou" from
`main` into `build/tv/` (`tools/tv_apk.sh beta` builds "Bijou Beta" from
`dev`); the session installs it over adb (docs/07-google-tv.md). It is
32-bit only and signed with the debug key, the same certificate as the
release's, so the two update each other.

## Other platforms

- **Mac:** possible, not built yet. Flutter, the player (media_kit /
  libmpv), the secure storage and the window code all run on macOS. It
  needs a Mac with Xcode to build and test on, FFmpeg builds for macOS for
  casting, and either an Apple developer account (about $99 a year) to
  sign it or a one-time "Open anyway" in System Settings. Roughly a
  phase of work, mostly packaging and testing.
- **Android phones, tablets and Chromebooks:** in progress (ADR-068).
  The same APK knows a phone from a TV and gives it a touch layout: the
  bottom bar on a phone held upright, the rail on a tablet, a touch
  player. Google Play's bundle, listing and policy pages are in
  docs/play/; publishing waits for the remaining screens and the
  developer account.
- **iPhone and iPad:** the most work. It needs the touch layouts above,
  a Mac with Xcode, and an Apple developer account to install it for
  more than 7 days at a time (or App Store review). iOS doesn't let an
  app run FFmpeg as its own program, so casting would have to be
  rebuilt on an FFmpeg library; playback, downloads and the rest carry
  over.
