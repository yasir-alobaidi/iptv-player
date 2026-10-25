#!/usr/bin/env bash
# Installs Bijou, or updates it, from its latest release on GitHub
# (docs/install/linux.md). For Ubuntu 22.04, 24.04 and newer, the systems
# made from them (Linux Mint, Pop!_OS, Zorin OS, elementary OS, …) and
# Debian 13; 64-bit Intel/AMD PCs. Published with each release as
# install-linux.sh, so that one line installs it:
#
#   curl -fsSL https://github.com/yasir-alobaidi/iptv-player/releases/latest/download/install-linux.sh | bash
#
# (or `wget -qO- … | bash` where curl isn't installed: it uses either.)
#
# Options (piped, after `bash -s --`):
#   --version stable-330   that release instead of the latest
#   --from FILE.tar.gz     a tarball from tools/package_linux.sh (tests)
#   --skip-packages        install no system packages (tests)
#   --remove               take away the app, its entry and its icons
#
# The app goes to ~/.local/share/bijou/app (where install_stable_linux.sh
# puts it too), in one move; the entry and icons as install_desktop_entry.sh
# installs them. The data in ~/.local/share/io.github.yasiralobaidi.iptvplayer
# (sources, favourites, history, settings) is never touched.
# Env (tests): BIJOU_DOWNLOAD_URL, the folder the files come from.
#
# Everything is in main(), called on the last line: a download cut short
# runs nothing, and nothing it runs can read the rest of the piped script.
set -euo pipefail

repo_url=https://github.com/yasir-alobaidi/iptv-player
id=io.github.yasiralobaidi.iptvplayer

say() { printf '%s\n' "$*"; }
fail() {
  printf '\nSorry: %s\n' "$*" >&2
  exit 1
}

# 0 when version $1 >= $2 (2.39 >= 2.35).
version_at_least() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

os_field() {
  sed -n "s/^$1=//p" "$os_release" | head -n1 | tr -d "\"'"
}

installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

usage() {
  say "Installs or updates Bijou (docs/install/linux.md)."
  say "  curl -fsSL $repo_url/releases/latest/download/install-linux.sh | bash"
  say "  … | bash -s -- --version stable-330   a given release"
  say "  … | bash -s -- --remove               remove Bijou (your data stays)"
  say "  bash install-linux.sh --from bijou-linux-x64-ubuntu24.04.tar.gz"
}

# Which build this system needs (target), and the system packages it
# needs (packages): what the bundle links (GTK 3, libsecret, libmpv; the
# release log's ldd lists them) and the GLES/EGL libraries Flutter's engine
# opens at run time (libGLESv2.so.2: without it the app aborts at start, as
# a clean 22.04 showed). apt brings the rest. Ubuntu 22.04's family:
# libmpv.so.1 (mpv 0.34); 24.04, newer and Debian 13: libmpv.so.2 and
# glibc 2.39 or newer, and GTK's t64 name. Read off ubuntu:22.04, 24.04,
# 26.04, 26.10 and debian:trixie (2026-10).
detect_system() {
  os_release="${BIJOU_OS_RELEASE:-/etc/os-release}"
  [[ -r "$os_release" ]] || fail "this doesn't look like Ubuntu or Debian (no /etc/os-release)."
  local os_id like codename glibc
  os_id="$(os_field ID)"
  like="$(os_field ID_LIKE)"
  codename="$(os_field UBUNTU_CODENAME)"
  os_name="$(os_field PRETTY_NAME)"
  os_name="${os_name:-$os_id}"
  glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"

  local arch
  arch="$(uname -m)"
  if [[ "$arch" != x86_64 ]]; then
    fail "Bijou for Linux is made for 64-bit Intel and AMD computers (x86_64); this one is $arch."
  fi

  local family=""
  if [[ "$os_id" == ubuntu || -n "$codename" || " $like " == *" ubuntu "* ]]; then
    family=ubuntu
  elif [[ "$os_id" == debian || " $like " == *" debian "* ]]; then
    family=debian
  fi
  if [[ -z "$family" || -z "$glibc" ]]; then
    fail "$os_name isn't one Bijou installs on by itself. It needs Ubuntu 22.04 or newer (or Linux Mint, Pop!_OS, Zorin OS, elementary OS made from it) or Debian 13."
  fi

  if version_at_least "$glibc" 2.39; then
    target=ubuntu24.04
    packages=(libgtk-3-0t64 libsecret-1-0 libmpv2 libgles2 libegl1)
  elif [[ "$family" == ubuntu ]] && version_at_least "$glibc" 2.35; then
    target=ubuntu22.04
    packages=(libgtk-3-0 libsecret-1-0 libmpv1 libgles2 libegl1)
  elif [[ "$family" == ubuntu ]]; then
    fail "$os_name is too old for Bijou: it needs Ubuntu 22.04 or newer (or a system made from it)."
  else
    fail "$os_name is too old for Bijou: it needs Debian 13 or newer."
  fi
}

# The system packages the build links that aren't installed yet, with
# apt-get (sudo asks for the password once).
install_packages() {
  local missing=() package
  for package in "${packages[@]}"; do
    installed "$package" || missing+=("$package")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0

  if [[ "$skip_packages" == 1 ]]; then
    say "Not installing ${missing[*]} (--skip-packages): Bijou won't start without them."
    return 0
  fi
  command -v apt-get >/dev/null || fail "no apt-get here to install ${missing[*]}."

  say ""
  say "Bijou needs a few parts that aren't on this computer yet:"
  for package in "${missing[@]}"; do
    case "$package" in
      libmpv*) say "  $package (the video player inside Bijou)" ;;
      libsecret*) say "  $package (keeps your sign-in passwords safe)" ;;
      libgtk*) say "  $package (draws Bijou's window)" ;;
      libgles* | libegl*) say "  $package (draws the picture with the graphics card)" ;;
      *) say "  $package" ;;
    esac
  done

  local sudo=()
  if [[ $EUID -ne 0 ]]; then
    command -v sudo >/dev/null ||
      fail "installing them needs sudo, which isn't here. Ask someone with admin rights to run: apt-get install ${missing[*]}"
    say "Installing them needs your password: the one you sign in to this computer with."
    say "(sudo asks for it; nothing shows while you type. Press Enter when done.)"
    sudo=(sudo)
  fi
  # </dev/null: when piped, the script itself is on standard input.
  if ! "${sudo[@]}" apt-get install -y "${missing[@]}" </dev/null; then
    say "Refreshing the list of packages, then trying again…"
    "${sudo[@]}" apt-get update </dev/null || true
    "${sudo[@]}" apt-get install -y "${missing[@]}" </dev/null ||
      fail "the packages didn't install. Run this, then the installer again:
  sudo apt-get update && sudo apt-get install ${missing[*]}
(On Debian without sudo: su -c 'apt-get update && apt-get install ${missing[*]}')"
  fi
  say ""
}

# fetch URL FILE [quiet]: with curl, or wget where there's no curl.
fetch() {
  if command -v curl >/dev/null; then
    if [[ "${3:-}" == quiet ]]; then
      curl -fsSL --retry 3 -o "$2" "$1"
    else
      curl -fL --retry 3 --progress-bar -o "$2" "$1"
    fi
  elif command -v wget >/dev/null; then
    if [[ "${3:-}" == quiet ]]; then
      wget -q -O "$2" "$1"
    else
      wget -q --show-progress --progress=bar:force:noscroll -O "$2" "$1"
    fi
  else
    fail "curl or wget is needed to download Bijou: sudo apt-get install curl"
  fi
}

# file name ($2) in a SHA256SUMS.txt ($1) → its checksum, or nothing.
checksum_for() {
  awk -v f="$2" '$2 == f || $2 == "*"f {print $1; exit}' "$1"
}

remove() {
  rm -f "$data/applications/$id.desktop"
  find "$data/icons/hicolor" -name "$id.*" -delete 2>/dev/null || true
  gtk-update-icon-cache -q -t "$data/icons/hicolor" 2>/dev/null || true
  update-desktop-database -q "$data/applications" 2>/dev/null || true
  rm -rf "$data/bijou"
  say "Bijou is removed."
  say "Your data (sources, favourites, history, settings) is still in"
  say "  $data/$id"
  say "Delete that folder too if you want it gone; installing Bijou again finds it."
}

main() {
  local version="" from="" skip_packages=0 do_remove=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        version="${2:?--version needs a release name, like stable-330}"
        shift 2
        ;;
      --from)
        from="${2:?--from needs a .tar.gz file}"
        shift 2
        ;;
      --skip-packages)
        skip_packages=1
        shift
        ;;
      --remove)
        do_remove=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
  done

  data="${XDG_DATA_HOME:-$HOME/.local/share}"
  local app="$data/bijou/app"

  if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    fail "run it without sudo: Bijou installs for you, not for the whole computer, and asks for your password only if it needs to."
  fi

  if [[ "$do_remove" == 1 ]]; then
    remove
    exit 0
  fi

  detect_system
  say "Installing Bijou on $os_name…"
  install_packages

  local name="bijou-linux-x64-$target.tar.gz"
  mkdir -p "$data/bijou"
  # Beside the app, so the new one moves into place in one step.
  work="$(mktemp -d "$data/bijou/.install.XXXXXX")"
  trap 'rm -rf "$work"' EXIT

  local tarball sums=""
  if [[ -n "$from" ]]; then
    [[ -f "$from" ]] || fail "no file at $from."
    tarball="$from"
    if [[ -f "$(dirname "$from")/SHA256SUMS.txt" ]]; then
      sums="$(dirname "$from")/SHA256SUMS.txt"
    else
      say "(No SHA256SUMS.txt beside $(basename "$from"): its checksum isn't checked.)"
    fi
  else
    local base="$repo_url/releases/latest/download"
    [[ -n "$version" ]] && base="$repo_url/releases/download/$version"
    base="${BIJOU_DOWNLOAD_URL:-$base}"
    say "Downloading Bijou ($name, about 150 MB)…"
    fetch "$base/SHA256SUMS.txt" "$work/SHA256SUMS.txt" quiet ||
      fail "couldn't reach $base. Check the internet connection${version:+ and the release name ($version)}, then try again."
    fetch "$base/$name" "$work/$name" ||
      fail "the download stopped. Check the internet connection, then try again."
    tarball="$work/$name"
    sums="$work/SHA256SUMS.txt"
  fi

  if [[ -n "$sums" ]]; then
    local expected actual
    expected="$(checksum_for "$sums" "$(basename "$tarball")")"
    [[ -n "$expected" ]] || fail "$(basename "$tarball") isn't in SHA256SUMS.txt."
    actual="$(sha256sum "$tarball" | cut -d' ' -f1)"
    [[ "$actual" == "$expected" ]] ||
      fail "the download is damaged (its checksum doesn't match). Run the installer again."
    say "Download checked."
  fi

  tar -xzf "$tarball" -C "$work" ||
    fail "$(basename "$tarball") couldn't be unpacked."
  local new="$work/bijou"
  if [[ ! -x "$new/app/iptv_player" || ! -f "$new/packaging/$id.desktop" ]]; then
    fail "$(basename "$tarball") isn't a Bijou release."
  fi
  local built_for
  built_for="$(cat "$new/TARGET" 2>/dev/null || true)"
  if [[ -n "$built_for" && "$built_for" != "$target" ]]; then
    say "Note: this tarball is the $built_for build; this system needs the $target one."
  fi

  local running=0
  if command -v pgrep >/dev/null && pgrep -f "^$app/iptv_player" >/dev/null 2>&1; then
    running=1
  fi
  local updating=0
  [[ -d "$app" ]] && updating=1

  # The new app in place of the old one, in one move.
  rm -rf "$app.new" "$app.old"
  mv "$new/app" "$app.new"
  if [[ -d "$app" ]]; then mv "$app" "$app.old"; fi
  mv "$app.new" "$app"
  rm -rf "$app.old"

  # The app grid's entry and the icons (as tools/install_desktop_entry.sh).
  local binary="$app/iptv_player" escaped
  escaped="$(printf '%s' "$binary" | sed 's/[&|\\]/\\&/g')"
  mkdir -p "$data/applications"
  sed "s|^Exec=.*|Exec=\"$escaped\"|" "$new/packaging/$id.desktop" \
    > "$data/applications/$id.desktop"
  find "$data/icons/hicolor" -name "$id.*" -delete 2>/dev/null || true
  (cd "$new/packaging/icons" && find hicolor -type f) | while read -r icon; do
    mkdir -p "$data/icons/$(dirname "$icon")"
    cp "$new/packaging/icons/$icon" "$data/icons/$icon"
  done
  gtk-update-icon-cache -q -t "$data/icons/hicolor" 2>/dev/null || true
  update-desktop-database -q "$data/applications" 2>/dev/null || true

  # Anything the system still lacks: Bijou wouldn't start without it.
  local missing
  missing="$(
    {
      ldd "$binary" 2>/dev/null || true
      for lib in "$app"/lib/*.so; do
        LD_LIBRARY_PATH="$app/lib" ldd "$lib" 2>/dev/null || true
      done
    } | awk '/not found/ {print $1}' | sort -u | tr '\n' ' '
  )"

  local build
  build="$(sed -n 's/.*"build_number":"\([^"]*\)".*/\1/p' \
    "$app/data/flutter_assets/version.json" 2>/dev/null || true)"
  say ""
  if [[ -n "$missing" ]]; then
    say "Bijou is installed, but this computer still lacks: $missing"
    say "It won't start until they're there. For libmpv.so.1: sudo apt-get install libmpv1;"
    say "for libmpv.so.2: sudo apt-get install libmpv2. Then open Bijou from the app grid."
    exit 1
  fi
  if [[ "$updating" == 1 ]]; then
    say "Bijou is updated${build:+ (build $build)}. It's in your app grid."
  else
    say "Bijou${build:+ (build $build)} is in your app grid. Open it from there."
  fi
  if [[ "$running" == 1 ]]; then
    say "Bijou is open: close it and open it again to use the new version."
  fi
}

main "$@"
