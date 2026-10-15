# Setup

## Development machine — state checked on 2026-09-15
| Item | Status |
|---|---|
| OS / shell | Ubuntu 22.04.5 LTS (kernel 6.8), fish; Secure Boot off; about 690 GB free |
| git, curl, unzip, zip, xz-utils | installed |
| FFmpeg | system 4.4.2 — too old for the relay and never used. Bundled 8.1.2 (BtbN GPL) in `third_party/ffmpeg/linux-x64/`, fetched by `tools/fetch_ffmpeg.sh` on 2026-09-15 |
| libva for FFmpeg | system 2.14 (Ubuntu 22.04), too old for the bundled FFmpeg's VA-API. libva 2.22.0 built by `tools/fetch_libva.sh` into `third_party/libva/linux-x64/` on 2026-10-02 (docker) |
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
| Java | Temurin JDK 21.0.12.1 in `~/develop/jdk` (a link to `~/develop/jdk-21.0.12.1+1`), installed 2026-10-14; Flutter is pointed at it (`flutter config --jdk-dir`) |
| Android SDK / adb | `~/Android/Sdk`, installed 2026-10-14 (ADR-020): command-line tools 23, platform-tools 37.0.1 (`adb`), platforms 35 and 36, build-tools 36.0.0, NDK 28.2.13676358, emulator 37.2.12, the Google TV image `android-36;google-tv;x86_64`; AVD `bijou_google_tv` |

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
- `protobuf-compiler` (`protoc`) generates the Cast v2 protobuf code (ADR-002), committed in `lib/data/cast/proto/`. `tools/gen_cast_proto.sh` regenerates it, building `protoc-gen-dart` from the spike's pub cache, so no global activation is needed. Only needed if `cast_channel.proto` changes.
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

`tools/fetch_libva.sh` (Linux, needs docker or podman) builds libva 2.22.0 in a throwaway Ubuntu 22.04 container into `third_party/libva/linux-x64/` (gitignored). The bundled FFmpeg's VA-API needs libva 2.21 or newer, and Ubuntu 22.04 and 24.04 ship older ones (ADR-014 step 4). Without it, casting still works; re-encodes just never use VA-API (NVENC or the processor instead). The Linux build copies it into `bundle/ffmpeg/libva/`.

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

## 7. Google TV (Android)
Installed in the home folder, no sudo (ADR-020). To do it again on another machine:
```bash
# JDK 21 (Gradle 9 and AGP 9 need 17 or newer)
curl -LO https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz
tar -xzf OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz -C ~/develop && ln -sfn ~/develop/jdk-21.0.12.1+1 ~/develop/jdk
# The SDK's command-line tools, then what the build and the emulator need
curl -LO https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
mkdir -p ~/Android/Sdk/cmdline-tools && unzip -q commandlinetools-linux-16111833_latest.zip -d ~/Android/Sdk/cmdline-tools \
  && mv ~/Android/Sdk/cmdline-tools/cmdline-tools ~/Android/Sdk/cmdline-tools/latest
export JAVA_HOME=~/develop/jdk
yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --install platform-tools platforms/android-36 build-tools/36.0.0 \
  ndk/28.2.13676358 emulator system-images/android-36/google-tv/x86_64
flutter config --android-sdk ~/Android/Sdk --jdk-dir ~/develop/jdk
# A Google TV emulator (Android 16; 2 GB like the Chromecast with Google TV)
echo no | ~/Android/Sdk/cmdline-tools/latest/bin/avdmanager create avd -n bijou_google_tv \
  -k "system-images;android-36;google-tv;x86_64" -d tv_1080p
```
Fish: `fish_add_path ~/Android/Sdk/platform-tools` puts `adb` on PATH (scripts call it by its full path).

**Build and run:**
- `flutter build apk --release`: `build/app/outputs/flutter-apk/app-release.apk`, every ABI in one file (armeabi-v7a, arm64-v8a, x86_64), signed with the debug key until TV-5. `flutter build apk --debug` for the emulator.
- **Never build while the emulator runs** (2026-10-14 the two together ran the laptop out of memory and killed the desktop session): build, then `cd android && ./gradlew --stop`, then start the emulator; `adb emu kill` before the next build. Gradle is capped at 3 GB in `android/gradle.properties`.
- The emulator, headless: `~/Android/Sdk/emulator/emulator -avd bijou_google_tv -no-window -no-audio -no-boot-anim -no-snapshot-save -gpu swiftshader_indirect -memory 2048 &`, then `adb install -r <apk>`, `adb shell am start -W -n io.github.yasiralobaidi.bijou/.MainActivity`, `adb exec-out screencap -p > shot.png`, remote keys with `adb shell input keyevent KEYCODE_DPAD_DOWN` (…`_CENTER`, `KEYCODE_BACK`, `KEYCODE_TAB`) and text with `adb shell input text`. The laptop is `10.0.2.2` from inside it: the fake panel at `http://10.0.2.2:8899` (test / test). **mpv draws no picture on the emulator** (its EGL refuses mpv's context, ADR-020): sound, the decoder and the controls run, the picture needs a real TV.
- **A real Google TV, over Wi-Fi (no cable; ADR-025):** on the TV, Settings → System → About → press Android TV OS build seven times; Settings → System → Developer options → **Wireless debugging** on, then **Pair device with pairing code**: it shows an address:port and a six-digit code. On the laptop `adb pair <address>:<port> <code>` (once: the laptop stays paired), then `adb connect <address>:<connect port>` (the port Wireless debugging shows, or `avahi-browse -rtp _adb-tls-connect._tcp`; it changes when the TV restarts) and `adb install -r app-release.apk`. Android 14's Google TV opens no port 5555 for plain USB debugging. The Bedroom TV (a Chromecast with Google TV 4K in the Roku TV's HDMI 3) is `192.168.1.231`. Ask the user before every TV session; the Living Room TV is off limits until they say otherwise.
- **Without adb:** copy `dist/bijou-<version>.apk` (the release APK, copied there by hand after a build; `dist/` is ignored by git) to the TV with an app such as Send Files to TV or a USB stick through a file manager, and allow that app to install unknown apps when Android asks. An APK signed with another key (CI's) won't install over this one: uninstall first, which loses Bijou's data on the TV.
- **On the TV, read the log with** `adb logcat | grep ' flutter '`: the app's log goes there on Android (redacted), with each play's first frame. `adb shell input keyevent KEYCODE_HOME` (`_INFO`, `_CHANNEL_UP`, `_MEDIA_PLAY_PAUSE`, `_GUIDE`) are the remote's keys; `adb shell input tap x y` (1920 × 1080) is quicker for a test's setup. adb can't hold a key down (`--duration` sends both events at once).
