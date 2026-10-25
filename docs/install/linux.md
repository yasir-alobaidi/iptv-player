# Install Bijou on Linux

Bijou works on **Ubuntu 22.04 or newer** and the systems made from it
(**Linux Mint, Pop!_OS, Zorin OS, elementary OS**), and on **Debian 13**,
on an ordinary 64-bit PC. It takes about two minutes.

## Install

1. Open the **Terminal** (on Ubuntu, press **Ctrl + Alt + T**, or search
   for "Terminal" in your apps).
2. Copy this line, paste it into the Terminal (**Ctrl + Shift + V**) and
   press **Enter**:

   ```
   curl -fsSL https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh | bash
   ```

3. The first time, it may say that Bijou needs a few parts from your
   system (the video player inside Bijou, for example) and ask for
   **your password**: the one you sign in to the computer with. Type it
   and press **Enter**. Nothing shows while you type; that's normal.
4. Wait for the download (about 150 MB). When you see
   **"Bijou is in your app grid"**, it's done: close the Terminal.
5. Open your apps (on Ubuntu, the grid of dots at the bottom of the dock)
   and click **Bijou**. To keep it in the dock, right-click it there and
   choose **Pin to Dash** (or **Add to Favorites**).

If the Terminal says `curl: command not found`, use this line instead:

```
wget -qO- https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh | bash
```

## Update

Run the same line again (step 2). It downloads the newest Bijou and puts
it in place of the old one. Your sources, favourites, history, settings
and sign-ins stay as they are. If Bijou is open, close it and open it
again afterwards.

## Uninstall

In the Terminal:

```
curl -fsSL https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh | bash -s -- --remove
```

This removes the app and its icon. Your data stays, so installing Bijou
again brings everything back. To remove that too, delete the folder
`~/.local/share/io.github.yasiralobaidi.iptvplayer` (in Files, press
**Ctrl + H** to see hidden folders).

## Where things are

- **The app:** `~/.local/share/bijou/app`
- **Your data** (sources, favourites, history, settings):
  `~/.local/share/io.github.yasiralobaidi.iptvplayer`
- **Your passwords:** in the system's keyring (the **Passwords and Keys**
  app shows them), never in a file.

## If something goes wrong

- **"Sorry: … isn't one Bijou installs on by itself"** or **"… is too
  old"**: this system isn't one of those listed at the top. Bijou needs
  Ubuntu 22.04 or newer (or a system made from it) or Debian 13.
- **It stopped at the password:** your account may not be allowed to
  install software. Ask whoever set up the computer to run the line, or
  to install the parts it named (`sudo apt-get install …`), then run it
  again.
- **"the download is damaged"** or **"the download stopped"**: check the
  internet connection and run the line again.
- **Bijou doesn't open:** run it from the Terminal to see why:
  `~/.local/share/bijou/app/iptv_player`. If it names a missing
  `libmpv.so…`, install it (`sudo apt-get install libmpv1` on Ubuntu
  22.04 and its family, `libmpv2` on newer ones) and try again.
- **Casting finds the TV but nothing plays:** the TV fetches the video
  from this computer. Make sure both are on the same home network and
  that no VPN is on. If you turned on the firewall (`ufw`), let the TV
  in: `sudo ufw allow 38400:38499/tcp`.

**Without the one-line command:** download
[install-linux.sh](https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh)
and the file for your system from the
[latest release](https://github.com/yasir-alobaidi/iptv-player/releases/latest)
(`bijou-linux-x64-ubuntu22.04.tar.gz` for Ubuntu 22.04 and its family,
`…-ubuntu24.04.tar.gz` for anything newer and Debian 13), then in the
Terminal, in the folder you saved them to:
`bash install-linux.sh --from bijou-linux-x64-ubuntu24.04.tar.gz`.
