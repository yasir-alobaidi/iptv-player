#!/usr/bin/env bash
# Makes Bijou's Google Play upload key (docs/play/README.md, "Play App
# Signing and the upload key"): a keystore with one RSA key, outside the
# repository, never over one that is there.
#
#   tools/play_upload_key.sh                 ~/.android/bijou-play-upload.jks
#   tools/play_upload_key.sh <path>.jks      somewhere else (not in here)
#
# It asks for the password twice; the key and the keystore share it (a
# PKCS12 keystore has one). BIJOU_PLAY_DNAME changes the certificate's
# owner (default "CN=Bijou upload key"); only Google sees it.
#
# Play keeps the key that signs what it hands out (Play App Signing); this
# one only proves an upload is yours. If it's lost, Play can be asked to
# accept a new one (Play Console → Test and release → App integrity),
# which takes days: back it up.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
keystore=${1:-$HOME/.android/bijou-play-upload.jks}
alias=upload
dname=${BIJOU_PLAY_DNAME:-CN=Bijou upload key}

if [[ $# -gt 1 || $keystore == -* ]]; then
  echo "usage: $0 [keystore path, outside the repository]" >&2
  exit 2
fi

keytool=${KEYTOOL:-$HOME/develop/jdk/bin/keytool}
if [[ ! -x $keytool ]]; then
  keytool=$(command -v keytool || true)
fi
if [[ -z $keytool ]]; then
  echo "no keytool: install a JDK, or set KEYTOOL" >&2
  exit 1
fi

mkdir -p "$(dirname "$keystore")"
keystore="$(cd "$(dirname "$keystore")" && pwd)/$(basename "$keystore")"
case $keystore in
  "$repo"/*)
    echo "refusing: $keystore is inside the repository, which is public." >&2
    echo "Keep the key outside it (the default is ~/.android/bijou-play-upload.jks)." >&2
    exit 1
    ;;
esac
if [[ -e $keystore ]]; then
  echo "refusing: $keystore is already there. An upload key is made once;" >&2
  echo "move it away first only if you mean to replace it (Play then has to" >&2
  echo "be asked to accept the new one)." >&2
  exit 1
fi

echo "Making Bijou's upload key in $keystore."
echo "Choose a long password (12 characters or more) and save it in your"
echo "password manager first: nothing can recover it."
read -rsp "Password: " password
echo
read -rsp "Again: " again
echo
if [[ $password != "$again" ]]; then
  echo "the two passwords differ; nothing was made" >&2
  exit 1
fi
if ((${#password} < 12)); then
  echo "a password of 12 characters or more, please; nothing was made" >&2
  exit 1
fi
# To keytool through its environment, never on its command line (which
# other users' `ps` can read).
export BIJOU_NEW_KEY_PASSWORD=$password
unset password again

"$keytool" -genkeypair -keystore "$keystore" -storetype PKCS12 \
  -storepass:env BIJOU_NEW_KEY_PASSWORD -keypass:env BIJOU_NEW_KEY_PASSWORD \
  -alias "$alias" -keyalg RSA -keysize 4096 -validity 10000 -dname "$dname"
chmod 600 "$keystore"

echo
"$keytool" -list -v -keystore "$keystore" -alias "$alias" \
  -storepass:env BIJOU_NEW_KEY_PASSWORD |
  grep -E '^(Owner|Valid from|[[:space:]]*SHA256):' || true
unset BIJOU_NEW_KEY_PASSWORD

cat <<EOF

Done. Now:

1. Back it up: $keystore and its password, in two
   places that aren't this laptop (a password manager can hold both; an
   offline USB stick too). Never in the repository.

2. GitHub → the repository → Settings → Secrets and variables → Actions →
   New repository secret, four times:

     BIJOU_PLAY_KEYSTORE_BASE64    the line \`base64 -w0 $keystore\` prints
     BIJOU_PLAY_KEYSTORE_PASSWORD  the password
     BIJOU_PLAY_KEY_ALIAS          $alias
     BIJOU_PLAY_KEY_PASSWORD       the same password

3. To build the bundle on this laptop (tools/play_bundle.sh), in bash:

     export BIJOU_PLAY_KEYSTORE=$keystore
     export BIJOU_PLAY_KEY_ALIAS=$alias
     read -rsp 'Password: ' BIJOU_PLAY_KEYSTORE_PASSWORD; echo
     export BIJOU_PLAY_KEYSTORE_PASSWORD BIJOU_PLAY_KEY_PASSWORD=\$BIJOU_PLAY_KEYSTORE_PASSWORD
     tools/play_bundle.sh

   or in fish:

     set -x BIJOU_PLAY_KEYSTORE $keystore
     set -x BIJOU_PLAY_KEY_ALIAS $alias
     read -s -x -P 'Password: ' BIJOU_PLAY_KEYSTORE_PASSWORD
     set -x BIJOU_PLAY_KEY_PASSWORD \$BIJOU_PLAY_KEYSTORE_PASSWORD
     tools/play_bundle.sh
EOF
