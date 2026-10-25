#!/usr/bin/env bash
# The release's installers into dist/ (docs/install.md): what GitHub built
# for the latest `stable-*` tag, or for the one named. The Windows setup
# can only be built on Windows, so it comes from there (ADR-056).
#
#   tools/fetch_release.sh                  # Bijou-Setup.exe and Bijou-TV.apk
#   tools/fetch_release.sh all              # and the Linux installer and tarballs
#   tools/fetch_release.sh all stable-338   # a given release
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
url=https://github.com/yasir-alobaidi/iptv-player/releases
files=(Bijou-Setup.exe Bijou-TV.apk)
if [[ ${1:-} == all ]]; then
  files+=(install-linux.sh bijou-linux-x64-ubuntu22.04.tar.gz bijou-linux-x64-ubuntu24.04.tar.gz)
  shift
fi
base=$url/latest/download
[[ -n ${1:-} ]] && base=$url/download/$1

mkdir -p "$repo/dist"
cd "$repo/dist"
if ! curl -fsSL --retry 3 -o SHA256SUMS.txt "$base/SHA256SUMS.txt"; then
  echo "No release at $base yet: push a stable-* tag with the signing secrets in place (docs/install.md), and wait for the Release run." >&2
  exit 1
fi
for file in "${files[@]}"; do
  echo "$file"
  curl -fL --retry 3 --progress-bar -o "$file.part" "$base/$file"
  mv "$file.part" "$file"
done
grep -E " ($(IFS='|'; echo "${files[*]}"))\$" SHA256SUMS.txt | sha256sum -c -
echo "In $repo/dist."
