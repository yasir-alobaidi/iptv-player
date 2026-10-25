# Install Bijou on a TV (Google TV, Android TV, Fire TV)

Bijou for TV works on:

- **Google TV:** Chromecast with Google TV, Google TV Streamer, and TVs
  with Google TV built in (Sony, TCL, Hisense and others).
- **Android TV:** TVs and boxes with Android TV (Nvidia Shield, Philips,
  Xiaomi Mi Box and others).
- **Amazon Fire TV** with Fire OS: Fire TV Stick, Stick 4K, Stick 4K Max,
  Cube, and Fire TV smart TVs ([below](#fire-tv)).

It does **not** work on the built-in system of Roku, Samsung or LG TVs,
on Apple TV, or on the **Fire TV Stick 4K Select** (its new system
doesn't run Android apps). For those TVs, plug in a Google TV streamer or
a Fire TV stick and install Bijou there.

Bijou isn't in the Play Store: it is one file, **`Bijou-TV.apk`**
(about 95 MB), installed on the TV by hand. **None of the ways below
needs Developer options' "wireless debugging" or "USB debugging"**, only
permission for one app to install apps. It takes about ten minutes the
first time; updates take two, and keep everything (sign-in, sources,
favourites).

**Which way?**

| You have… | Do this |
|---|---|
| `Bijou-TV.apk` on a computer on the same Wi-Fi as the TV | [From a computer over Wi-Fi](#from-a-computer-over-wi-fi-the-fastest), the fastest |
| nothing yet, and the TV has internet | [Google TV and Android TV](#google-tv-and-android-tv) or [Fire TV](#fire-tv): Downloader and the address |
| the file on a USB stick | [From a USB stick](#from-a-usb-stick) |
| the file on an Android phone | [From a phone](#from-a-phone-instead-of-typing) |

The file itself: in this project it is **`dist/Bijou-TV.apk`**
(`tools/dist_apk.sh` makes it; docs/install.md); the newest release's is
at the address in [step 3](#3-install-bijou).

## Google TV and Android TV

### 1. Get the Downloader app (once)

On the TV, open the **Play Store** (or **Search** on Google TV's home
screen), search for **Downloader**, choose **Downloader by AFTVnews**
(an orange icon) and select **Install**.

### 2. Allow Downloader to install apps (once)

1. Open **Settings** (on Google TV: your profile picture at the top
   right, then **Settings**) → **System** → **About**.
2. Scroll to the bottom to **Android TV OS build** and press **OK** on
   the remote seven times, until it says **"You are now a developer!"**.
3. Go back to **Settings** → **Apps** → **Security & restrictions** →
   **Unknown sources**, and switch **Downloader** on (**Allowed**).
   On some TVs this menu isn't there: Downloader asks for it itself in
   step 3 below (select **Settings**, switch **Downloader** on, and press
   **Back**).

### 3. Install Bijou

1. Open **Downloader**. If it asks for access to files, select **Allow**.
2. Select the box at the top (it says *Enter a URL…*), type this, and
   select **Go**:

   ```
   github.com/yasir-alobaidi/iptv-player/releases/latest/download/Bijou-TV.apk
   ```

   Type it exactly: small letters, the dashes and the slashes. It
   downloads (about 95 MB).
3. Select **Install**.
   - If **Google Play Protect** warns that the app is unknown or
     blocked, select **More details** (or **Details**) → **Install
     anyway**. Play Protect warns because Bijou doesn't come from the
     Play Store.
4. When it says *App installed*, select **Done**.
5. Downloader then offers to **Delete** the downloaded file: select
   **Delete** (and **Delete** again if it asks). Bijou stays installed;
   this only frees the space.

Bijou is now in your apps (on Google TV: the **Apps** tab → **Your
apps**). Open it and sign in to your services or add your playlists.

## Fire TV

1. **Get Downloader:** on the Fire TV's home screen, select **Find** (the
   magnifying glass) → **Search**, type **Downloader**, choose
   **Downloader** (by AFTVnews) and select **Get** (or **Download**).
2. **Turn on developer options:** **Settings** → **My Fire TV** →
   **About**, then press **OK** seven times on the first line (your
   device's name, for example *Fire TV Stick 4K*), until it says you are
   a developer.
3. **Allow Downloader:** go back to **My Fire TV** → **Developer
   options** → **Install unknown apps** → switch **Downloader** to
   **On**. (On older Fire TVs the line is **Apps from Unknown Sources** →
   **Turn On**.) If Downloader isn't in the list, restart the Fire TV,
   open **Settings**, wait a minute and look again.
4. **Install Bijou:** open Downloader and follow
   [step 3 above](#3-install-bijou) (the same address, **Go**,
   **Install**, **Done**, **Delete**).

Bijou is in your list of apps (the apps button on the home screen, or
**Settings** → **Applications** → **Manage Installed Applications**).

## From a computer over Wi-Fi (the fastest)

For a TV on the same Wi-Fi as a computer that has `Bijou-TV.apk`. No
cable, no debugging, no link on the internet: the TV downloads the file
straight from the computer.

1. **On the TV, once:** do [part 1](#1-get-the-downloader-app-once) and
   [part 2](#2-allow-downloader-to-install-apps-once) above (on Fire TV,
   its [steps 1–3](#fire-tv)): Downloader, allowed to install apps.
2. **On the computer**, in the project folder, in a Terminal:

   ```
   python3 tools/serve_apk.py
   ```

   It shows an address such as **`192.168.1.20:8000`**. (Another file:
   `python3 tools/serve_apk.py path/to/Bijou-TV.apk`. Any computer with
   Python 3 can do it with this one script and the APK.)
3. **On the TV**, open **Downloader**, type that address in the box at
   the top (just the numbers, the dots and `:8000`), and select **Go**.
   The file downloads at once.
4. Select **Install**, then **Done**, then **Delete** (the downloaded
   file; Bijou stays). If Google Play Protect warns, **More details** →
   **Install anyway**.
5. On the computer, press **Ctrl + C** to stop.

If the TV can't reach the address: both must be on the same network (not
a guest Wi-Fi), and a firewall on the computer must let port 8000 in
(Ubuntu's is off unless turned on: `sudo ufw allow 8000/tcp`).

## From a USB stick

For a TV or box with a USB port (a Chromecast with Google TV has only its
USB-C power port: it needs a USB-C hub with power through).

1. Copy `Bijou-TV.apk` onto a USB stick and plug it into the TV.
2. On the TV, from the **Play Store**, install a file manager, e.g.
   **X-plore File Manager** (or **File Commander**).
3. Allow it to install apps: **Settings** → **Apps** → **Security &
   restrictions** → **Unknown sources** → switch the file manager on
   (after turning on Developer options as in
   [part 2](#2-allow-downloader-to-install-apps-once); some TVs ask by
   themselves at the next step).
4. In the file manager, open the USB stick, select **Bijou-TV.apk**, and
   **Install**.

## From a phone instead of typing

1. On an Android phone, open
   `https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/Bijou-TV.apk`
   to download the file (don't install it on the phone).
2. Install **Send files to TV** (by Yablio) from the Play Store on the
   phone and on the TV, and open it on both; they must be on the same
   Wi-Fi.
3. On the TV select **Receive**; on the phone select **Send**, pick
   **Bijou-TV.apk** from **Downloads**, and choose your TV.
4. On the TV, open the received file and select **Install**. The first
   time, the TV asks to allow **Send files to TV** to install apps:
   select **Settings**, switch it on, press **Back**, and **Install**.

## Update

Do [step 3](#3-install-bijou) again: Downloader, the same address, **Go**,
**Install**. Android says it's an update to an app already there and
keeps everything: your sign-in, sources, favourites and settings.

The downloaded Bijou also updates a Bijou put on the TV from the laptop
(the same app). "Bijou Beta" is a different app and isn't touched.

## Uninstall

- **Google TV / Android TV:** **Settings** → **Apps** → **Bijou** →
  **Uninstall** → **OK**.
- **Fire TV:** **Settings** → **Applications** → **Manage Installed
  Applications** → **Bijou** → **Uninstall**.

Uninstalling deletes Bijou's data on the TV (sign-in, favourites,
settings); install it again and sign in once more.

## For developers: adb

With **USB debugging** or **wireless debugging** on (Developer options),
from the project folder: `adb connect <TV's address>:<port>` (wireless),
then `adb install -r dist/Bijou-TV.apk`. Not needed for anything above.

## If something goes wrong

- **Downloader says *"Unknown sources" is disabled*** or nothing happens
  after the download: part 2 (or step 3 on Fire TV) didn't take; do it
  again.
- **The download fails or the address isn't found:** check the address
  letter by letter (it starts with `github.com/yasir-alobaidi/`), and the
  TV's internet connection.
- **"App not installed"** when updating: the Bijou on the TV was made
  with a different key (an old test version). Uninstall Bijou, then
  install it again.
- **"There was a problem parsing the package":** the download was cut
  short; download it again.
- **Not enough space:** delete the downloaded file in Downloader (its
  **Files** tab) and other files you don't need, then try again.
