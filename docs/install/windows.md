# Install Bijou on Windows

For **Windows 10 and 11** (64-bit). It takes about two minutes.

## Install

1. Download **[Bijou-Setup.exe](https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/Bijou-Setup.exe)**
   (over 100 MB).
   - If Edge says *"Bijou-Setup.exe isn't commonly downloaded"*: point at
     the download, click **…** (More actions) → **Keep** → **Show more**
     → **Keep anyway**.
2. Open the downloaded file (click it in the browser's downloads, or
   double-click it in your **Downloads** folder).
3. Windows shows a blue box, **"Windows protected your PC"**. This is
   because Bijou is a small personal app that isn't registered with
   Microsoft, not because something is wrong. Click **More info**, then
   **Run anyway**.
4. Windows asks *"Do you want to allow this app from an unknown publisher
   to make changes to your device?"*. Click **Yes**. (Installing for
   everyone on the PC needs this once.)
5. In Bijou's setup:
   - **Select Additional Tasks:** *Create a desktop shortcut* is ticked;
     untick it if you don't want one. Click **Next**.
   - **Ready to Install:** click **Install**.
   - When it's done, leave **Launch Bijou** ticked and click **Finish**.

Bijou is now in the **Start** menu (and on the desktop). To pin it, right-
click it in Start and choose **Pin to Start** or **Pin to taskbar**.

The setup also lets your TV reach Bijou through **Windows Firewall** on
your home network, which casting needs. You don't have to answer any
firewall question; if Windows asks anyway, tick **Private networks** and
click **Allow**.

## Update

Download **Bijou-Setup.exe** again with the same link and open it, as in
steps 1 to 5. It replaces the old Bijou; your sources, favourites,
history, settings and sign-ins stay as they are. If Bijou is open, the
setup offers to close it: leave **Automatically close the applications**
selected and click **Next**.

## Uninstall

- **Windows 11:** Start → **Settings** → **Apps** → **Installed apps** →
  find **Bijou** → **…** → **Uninstall** → **Uninstall**.
- **Windows 10:** Start → **Settings** → **Apps** → **Apps & features** →
  **Bijou** → **Uninstall** → **Uninstall**.

Then answer **Yes** to *"Are you sure you want to completely remove
Bijou…?"*. This removes the app, its shortcuts and its firewall rule.
Your data stays, so installing Bijou again brings everything back. To
remove that too, delete the folder below.

## Where things are

- **The app:** `C:\Program Files\Bijou`
- **Your data** (sources, favourites, history, settings, sign-ins):
  `%APPDATA%\io.github.yasiralobaidi\IPTV Player` (type
  `%APPDATA%` in File Explorer's address bar and press **Enter** to get
  there; the folder still has the app's first name, "IPTV Player").

## If something goes wrong

- **There's no "Run anyway" button:** click **More info** first; the
  button appears under it. If your PC is managed by work or school, it
  may not allow apps from outside the Store.
- **Casting finds the TV but nothing plays:** the TV fetches the video
  from the PC, which Windows allows only on a network marked as private.
  Open **Settings** → **Network & internet** → **Wi-Fi** (or
  **Ethernet**) → your network, and set **Network profile type** to
  **Private network**. Turn off any VPN while casting.
- **Your antivirus removed or blocked a file:** Bijou carries FFmpeg
  (`C:\Program Files\Bijou\ffmpeg`) to send video to the TV. Allow it in
  the antivirus, then run the setup again.
- **You used an older Bijou from a zip file**
  (`%LOCALAPPDATA%\Programs\Bijou`): after installing this one, delete
  that folder. Both use the same data, so nothing is lost.
