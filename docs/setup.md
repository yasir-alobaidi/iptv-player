# Setup

## Development machine — state checked on 2026-09-15
| Item | Status |
|---|---|
| OS / shell | Ubuntu 22.04.5 LTS (kernel 6.8), fish; Secure Boot off; about 690 GB free |
| git, curl, unzip, zip, xz-utils | installed |
| FFmpeg | system 4.4.2 — too old for the relay and never used. Bundled 8.1.2 (BtbN GPL) in `third_party/ffmpeg/linux-x64/`, fetched by `tools/fetch_ffmpeg.sh` on 2026-09-15 |
| Flutter / Dart | 3.47.4 / 3.13.3 in `~/develop/flutter` (manual install). Scripts and non-interactive shells may not have it on PATH; call `~/develop/flutter/bin/flutter` there |
| Media samples | generated in `tools/media_samples/out/` (gitignored); regenerate with `tools/media_samples/generate.sh` |
| Build tools | clang 14.0.0, cmake 3.22.1, ninja 1.10.1, pkg-config 0.29.2 |
| mpv / libmpv | 0.34.1 (`mpv`, `libmpv-dev`) |
| Intel GPU (UHD, Comet Lake-H) | i915 with the iHD 22.3.1 VA-API driver (`intel-media-va-driver-non-free`); `vainfo` lists H.264, HEVC, and HEVC 10-bit |
| NVIDIA GPU (GTX 1650 Ti Mobile) | nvidia-driver-595-open (595.91.07), used through PRIME render offload; optional for the app (ADR-003) |
| Plugin libraries | libsecret-1-dev, libjsoncpp-dev, libmimalloc-dev installed |
| protoc | 3.12.4 (`protobuf-compiler`) |
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
- `libmpv-dev` on 22.04 is mpv 0.34.1. Phase 0 confirmed it works with media_kit, using our patched media_kit_video (ADR-003); the AppImage must bundle it (Phase 10).
- `libsecret-1-dev` and `libjsoncpp-dev` are needed by flutter_secure_storage on Linux.
- `libmimalloc-dev` is listed in media_kit's Linux install instructions.
- `protobuf-compiler` (`protoc`) generates the Cast v2 protobuf code (ADR-002). `spike/cast_spike/tool/gen_proto.sh` builds `protoc-gen-dart` from the pub cache, so no global activation is needed.
- Claude can't run sudo: it needs a password and the session has no terminal. Paste these into your own terminal.

## 2. GPU drivers (for hardware decode/encode tests)
```bash
ubuntu-drivers devices
sudo ubuntu-drivers autoinstall   # installs nvidia-driver-595-open, the recommended driver for this GPU; reboot afterwards
nvidia-smi                        # should list the GTX 1650 Ti
vainfo                            # should list H264 and HEVC profiles for the Intel GPU
```
Secure Boot is off on this laptop, so no key enrollment (MOK) screen appears after the reboot. Apps run on Intel by default; to run one on NVIDIA, set `__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia`.

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
`tools/fetch_ffmpeg.sh` downloads recent static ffmpeg/ffprobe builds into `third_party/ffmpeg/<platform>/` (gitignored). The app never calls the system FFmpeg. BtbN's `latest` release is rebuilt daily; set `FFMPEG_TAG` to a dated autobuild tag to pin a build before packaging.

## 5. Windows machine (builds and testing)
- Windows 10/11 on real hardware (VM GPU decoding isn't representative)
- Visual Studio 2022 with the "Desktop development with C++" workload
- Flutter stable and Git
- Clone the repo; `flutter run -d windows`

## 6. Casting network
- Laptop and Google TV / Chromecast on the same home network and subnet (not hotel or guest Wi-Fi, which usually isolate devices)
- Prefer Ethernet on the laptop when casting 4K. In Phase 0, 5 GHz Wi-Fi at 540 Mbit/s carried 15 Mbps 4K casts
- 4K needs the TV's full-bandwidth HDMI mode on the Chromecast's input. On the Samsung TV used in Phase 0 that's Input Signal Plus (Settings → General → External Device Manager); other brands have a similar per-input setting. Without it the Chromecast never offers 4K and refuses every 4K stream (ADR-004)
- Cast discovery with multicast_dns works alongside avahi-daemon (ADR-004)
- If `ufw` is active: `sudo ufw allow 38400:38499/tcp`
- Tested device: "Living Room TV", a Chromecast with Google TV (4K) (ADR-004)

## 7. Google TV phase (later)
Android Studio (SDK, platform-tools/adb, an Android TV emulator image for layout checks), a real Google TV device, developer options with network or USB debugging enabled on the device.
