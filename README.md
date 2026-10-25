# Bijou

*Your own little cinema.* A fast, keyboard-first video player for Linux and Windows: your own video files, the playlists and program guides you add (M3U, XMLTV) and the services you sign in to, cast to Chromecast / Google TV at original quality, with downloads for offline viewing. It comes with no content of its own. A Google TV version follows the desktop v1.

The name, the icon and how the app describes itself: docs/05-design-system.md, "Brand" (ADR-018). The repository, the Dart package and the application id keep their first name, `iptv-player`.

## Install

- **Windows 10 and 11:** download [Bijou-Setup.exe](https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/Bijou-Setup.exe) and open it. [Step by step](docs/install/windows.md).
- **Linux** (Ubuntu 22.04 or newer, Linux Mint, Pop!_OS, Zorin OS, elementary OS, Debian 13): in a Terminal, `curl -fsSL https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh | bash`. [Step by step](docs/install/linux.md).
- **Google TV, Android TV, Fire TV:** the file `Bijou-TV.apk` (in this project, `dist/Bijou-TV.apk`), installed with the free Downloader app from this computer over Wi-Fi (`python3 tools/serve_apk.py`) or from `github.com/yasir-alobaidi/iptv-player/releases/latest/download/Bijou-TV.apk`; no debugging needed. [Step by step](docs/install/android-tv.md).

The same links always give the newest release. How releases are made: `docs/install.md`.

## Start here
1. Do the system setup in `docs/setup.md` (sudo steps are manual).
2. Open Claude Code in this folder.
3. Paste the **Phase 0** prompt from `docs/08-phases-and-prompts.md`.
4. When Claude asks, tell it your Google TV / Chromecast model and whether you have a real Windows PC.

To build the stable app yourself, make a release, and keep the code pushed: `docs/install.md`.

Specs live in `docs/`. Rules for Claude Code live in `CLAUDE.md`.
