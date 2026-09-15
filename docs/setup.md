# Setup

## Development machine — state checked on 2026-09-15
| Item | Status |
|---|---|
| OS / shell | Ubuntu 22.04.5 LTS (kernel 6.8), fish; Secure Boot off; about 700 GB free |
| git, curl, unzip, zip, xz-utils | installed |
| FFmpeg | system 4.4.2 — too old for the relay and never used. Bundled 8.1.2 (BtbN GPL) in `third_party/ffmpeg/linux-x64/`, fetched by `tools/fetch_ffmpeg.sh` on 2026-09-15 |
| Flutter / Dart | 3.47.4 / 3.13.3 extracted to `~/develop/flutter` by Claude on 2026-09-15 (no sudo needed). **Not on PATH yet:** run `fish_add_path ~/develop/flutter/bin` |
| Media samples | generated in `tools/media_samples/out/` (gitignored); regenerate with `tools/media_samples/generate.sh` |
| Build tools (clang, cmake, ninja, pkg-config, GTK dev headers) | not installed |
| mpv / libmpv | not installed (apt candidate libmpv-dev 0.34.1) |
| Intel GPU (UHD 630, Comet Lake-H) | i915 driver; free intel-media-va-driver installed; `vainfo` not installed |
| NVIDIA GPU (GTX 1650 Ti Mobile) | open-source nouveau driver in use; `ubuntu-drivers` recommends nvidia-driver-595-open |
| mDNS (avahi-daemon) | installed and running |
| Firewall (ufw) | inactive |
| multiverse repository | enabled |
| Android SDK / adb / Java | not installed (needed only for the Google TV phase) |

## 1. System packages (run yourself — needs sudo)
```bash
sudo apt update
sudo apt install -y curl git unzip xz-utils zip libglu1-mesa \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libsecret-1-dev libjsoncpp-dev \
  libmpv-dev mpv libmimalloc-dev \
  vainfo intel-media-va-driver-non-free \
  avahi-daemon protobuf-compiler
```
Notes:
- `intel-media-va-driver-non-free` is in the multiverse repository (`sudo add-apt-repository multiverse` if apt can't find it).
- `libmpv-dev` on 22.04 is mpv 0.34. Phase 0 checks whether media_kit works well with it; if not, install a newer libmpv and record the choice in docs/decisions.md.
- `libsecret-1-dev` and `libjsoncpp-dev` are needed by flutter_secure_storage on Linux.
- `libmimalloc-dev` is listed in media_kit's Linux install instructions.
- `protobuf-compiler` (`protoc`) is used once to generate the Cast v2 protobuf code (ADR-002).
- Claude can't run sudo: it needs a password and the session has no terminal. Paste these into your own terminal.

## 2. GPU drivers (for hardware decode/encode tests)
```bash
ubuntu-drivers devices
sudo ubuntu-drivers autoinstall   # installs nvidia-driver-595-open, the recommended driver for this GPU; reboot afterwards
nvidia-smi                        # should list the GTX 1650 Ti
vainfo                            # should list H264 and HEVC profiles for the Intel GPU
```
Secure Boot is off on this laptop, so no key enrollment (MOK) screen appears after the reboot.

## 3. Flutter SDK
Use Flutter's manual install (https://docs.flutter.dev/install/manual) rather than the snap: download the latest stable Linux bundle linked from that page, then:
```bash
mkdir -p ~/develop
tar -xf ~/Downloads/flutter_linux_<version>-stable.tar.xz -C ~/develop/
```
Fish shell PATH: `fish_add_path ~/develop/flutter/bin` (then open a new terminal).
```bash
flutter config --enable-linux-desktop --enable-windows-desktop
flutter doctor -v
```

## 4. FFmpeg for the app
Phase 0 creates `tools/fetch_ffmpeg.sh`, which downloads recent static ffmpeg/ffprobe builds into `third_party/ffmpeg/<platform>/` (gitignored). The app never calls the system FFmpeg.

## 5. Windows machine (builds and testing)
- Windows 10/11 on real hardware (VM GPU decoding isn't representative)
- Visual Studio 2022 with the "Desktop development with C++" workload
- Flutter stable and Git
- Clone the repo; `flutter run -d windows`

## 6. Casting network
- Laptop and Google TV / Chromecast on the same home network and subnet (not hotel or guest Wi-Fi, which usually isolate devices)
- Prefer Ethernet on the laptop when casting 4K
- If `ufw` is active: `sudo ufw allow 38400:38499/tcp`
- Record the Google TV / Chromecast model(s) in docs/decisions.md (ADR-004)

## 7. Google TV phase (later)
Android Studio (SDK, platform-tools/adb, an Android TV emulator image for layout checks), a real Google TV device, developer options with network or USB debugging enabled on the device.
