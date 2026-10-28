#!/usr/bin/env bash
# Builds the app bundle for Google Play (docs/play/README.md) as
# dist/Bijou-Play.aab: "Bijou" with the jewel, for 32- and 64-bit ARM and
# 64-bit Intel (phones, tablets, Chromebooks, TVs; Play hands each device
# only its own part), signed with the Play upload key, never the debug one.
# The release workflow's "Google Play bundle" job makes the same file.
#
#   tools/play_bundle.sh        from the checkout as it is (main for stable)
#
# It needs the upload key (tools/play_upload_key.sh) in BIJOU_PLAY_KEYSTORE,
# with BIJOU_PLAY_KEYSTORE_PASSWORD, BIJOU_PLAY_KEY_ALIAS and
# BIJOU_PLAY_KEY_PASSWORD. Then it checks the bundle: every 64-bit library
# aligned for 16 KB pages (Play refuses others), and prints the version and
# the certificate that signed it. Upload it by hand in the Play Console.
# Run nothing else with flutter in this checkout while it builds; Gradle is
# stopped afterwards (the laptop's memory).
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
flutter=${FLUTTER:-$HOME/develop/flutter/bin/flutter}
[[ -x $flutter ]] || flutter=$(command -v flutter || echo flutter)
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}
app_id=io.github.yasiralobaidi.bijou

if [[ $# -gt 0 ]]; then
  echo "usage: $0 (no arguments; the key comes from BIJOU_PLAY_KEYSTORE)" >&2
  exit 2
fi

# The upload key, before anything is built.
if [[ -z ${BIJOU_PLAY_KEYSTORE:-} ]]; then
  cat >&2 <<'EOF'
BIJOU_PLAY_KEYSTORE isn't set: Google Play takes a bundle signed only with
its upload key, never with the debug key that signs the TVs' APK, so none
is built without it. Make the key once with tools/play_upload_key.sh, then
set BIJOU_PLAY_KEYSTORE, BIJOU_PLAY_KEYSTORE_PASSWORD, BIJOU_PLAY_KEY_ALIAS
and BIJOU_PLAY_KEY_PASSWORD (docs/play/README.md).
EOF
  exit 1
fi
if [[ ! -f $BIJOU_PLAY_KEYSTORE ]]; then
  echo "BIJOU_PLAY_KEYSTORE: no keystore at $BIJOU_PLAY_KEYSTORE" >&2
  exit 1
fi
for name in BIJOU_PLAY_KEYSTORE_PASSWORD BIJOU_PLAY_KEY_ALIAS BIJOU_PLAY_KEY_PASSWORD; do
  if [[ -z ${!name:-} ]]; then
    echo "BIJOU_PLAY_KEYSTORE is set but $name isn't (docs/play/README.md)" >&2
    exit 1
  fi
done
BIJOU_PLAY_KEYSTORE=$(cd "$(dirname "$BIJOU_PLAY_KEYSTORE")" && pwd)/$(basename "$BIJOU_PLAY_KEYSTORE")
export BIJOU_PLAY_KEYSTORE BIJOU_PLAY_KEYSTORE_PASSWORD BIJOU_PLAY_KEY_ALIAS BIJOU_PLAY_KEY_PASSWORD

keytool=${KEYTOOL:-$HOME/develop/jdk/bin/keytool}
[[ -x $keytool ]] || keytool=${JAVA_HOME:+$JAVA_HOME/bin/keytool}
[[ -n $keytool && -x $keytool ]] || keytool=$(command -v keytool || true)
if [[ -z $keytool ]]; then
  echo "no keytool: install a JDK, or set KEYTOOL" >&2
  exit 1
fi
# The password reaches keytool through its environment, not its command line.
if ! key=$("$keytool" -list -v -keystore "$BIJOU_PLAY_KEYSTORE" \
  -alias "$BIJOU_PLAY_KEY_ALIAS" -storepass:env BIJOU_PLAY_KEYSTORE_PASSWORD 2>&1); then
  echo "the upload key won't open: check BIJOU_PLAY_KEYSTORE_PASSWORD and BIJOU_PLAY_KEY_ALIAS" >&2
  echo "$key" | grep -i 'error' >&2 || true
  exit 1
fi
owner=$(sed -n 's/^Owner: //p' <<<"$key" | head -n1)
key_sha256=$(sed -n 's/^[[:space:]]*SHA256: //p' <<<"$key" | head -n1)
if [[ $owner == *"CN=Android Debug"* ]]; then
  echo "refusing: $BIJOU_PLAY_KEYSTORE holds a debug key ($owner)," >&2
  echo "which Google Play rejects. Use the upload key (tools/play_upload_key.sh)." >&2
  exit 1
fi

# The version code is the commit count, as the Gradle file's; Play takes
# only a code higher than the last upload's, and a shallow clone counts 1.
if [[ $(git -C "$repo" rev-parse --is-shallow-repository) == true ]]; then
  echo "refusing: a shallow clone counts too few commits for the version code;" >&2
  echo "fetch the whole history first (git fetch --unshallow)" >&2
  exit 1
fi
build=$(git -C "$repo" rev-list --count HEAD)
branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD)
main=$(git -C "$repo" rev-parse --verify -q main || true)
if [[ -n $main && $(git -C "$repo" rev-parse HEAD) != "$main" ]]; then
  echo "note: building '$branch', which isn't main (the stable build)" >&2
fi
if [[ -n $(git -C "$repo" status --porcelain --untracked-files=no) ]]; then
  echo "note: the checkout has uncommitted changes; build $build won't be exactly the commit" >&2
fi

cd "$repo"
"$flutter" build appbundle --release \
  --target-platform android-arm,android-arm64,android-x64 \
  --build-number="$build"
mkdir -p dist
cp build/app/outputs/bundle/release/app-release.aab dist/Bijou-Play.aab
# Gradle's --stop needs the JDK the build used (Flutter's jdk-dir).
jdk=$("$flutter" config --list 2>/dev/null | sed -n 's/^ *jdk-dir: //p')
(cd android && JAVA_HOME=${JAVA_HOME:-$jdk} ./gradlew --stop >/dev/null 2>&1) ||
  pkill -f '[G]radleDaemon' || true
pkill -f '[K]otlinCompileDaemon' || true

# The checks, on the bundle itself.
aab=$repo/dist/Bijou-Play.aab
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unzip -q "$aab" 'base/lib/*' 'base/manifest/AndroidManifest.xml' -d "$work"

problems=0
for abi in armeabi-v7a arm64-v8a x86_64; do
  if [[ ! -f $work/base/lib/$abi/libflutter.so ]]; then
    echo "error: the bundle has no base/lib/$abi/libflutter.so" >&2
    problems=$((problems + 1))
  fi
done

# Play's 16 KB page rule (Android 15 and up): each LOAD segment of a 64-bit
# library aligned to 0x4000 or more. The NDK's llvm-readelf, else readelf.
readelf=${READELF:-}
if [[ -z $readelf ]]; then
  readelf=$(find "$sdk"/ndk/*/toolchains/llvm/prebuilt/linux-x86_64/bin \
    -name llvm-readelf 2>/dev/null | sort -V | tail -n1 || true)
fi
[[ -n $readelf ]] || readelf=$(command -v llvm-readelf || command -v readelf || true)
if [[ -z $readelf ]]; then
  echo "error: no llvm-readelf (the NDK's) or readelf to check the libraries with" >&2
  problems=$((problems + 1))
else
  checked=0
  while IFS= read -r -d '' so; do
    aligns=$("$readelf" -lW "$so" | awk '$1 == "LOAD" { print $NF }')
    if [[ -z $aligns ]]; then
      echo "error: ${so#"$work"/}: no LOAD segments read" >&2
      problems=$((problems + 1))
      continue
    fi
    for align in $aligns; do
      if ((align < 0x4000)); then
        echo "error: ${so#"$work"/} has a LOAD segment aligned to $align, under 16 KB" >&2
        problems=$((problems + 1))
        break
      fi
    done
    checked=$((checked + 1))
  done < <(find "$work/base/lib/arm64-v8a" "$work/base/lib/x86_64" -name '*.so' -print0 2>/dev/null)
  echo "16 KB pages: $checked 64-bit libraries checked"
fi

# The version Play reads, from the bundle's manifest (aapt2 reads it from a
# zip of its own).
aapt2=${AAPT2:-$(find "$sdk"/build-tools -name aapt2 -type f 2>/dev/null | sort -V | tail -n1 || true)}
if [[ -n $aapt2 ]] && command -v zip >/dev/null; then
  (cd "$work/base/manifest" && zip -q "$work/manifest.zip" AndroidManifest.xml)
  manifest=$("$aapt2" dump xmltree --file AndroidManifest.xml "$work/manifest.zip")
  version_code=$(sed -n 's/.*:versionCode([^)]*)=\([0-9]*\).*/\1/p' <<<"$manifest" | head -n1)
  version_name=$(sed -n 's/.*:versionName([^)]*)="\([^"]*\)".*/\1/p' <<<"$manifest" | head -n1)
  package=$(sed -n 's/^ *A: package="\([^"]*\)".*/\1/p' <<<"$manifest" | head -n1)
  if [[ $version_code != "$build" ]]; then
    echo "error: the bundle's version code is $version_code, not the commit count $build" >&2
    problems=$((problems + 1))
  fi
  # The id Play's listing is made for: not Bijou Beta's (ADR-034).
  if [[ $package != "$app_id" ]]; then
    echo "error: the bundle's app id is $package, not $app_id" >&2
    problems=$((problems + 1))
  fi
else
  echo "note: no aapt2 (in $sdk/build-tools) or zip to read the bundle's manifest with" >&2
  version_code="$build (expected)"
  version_name="$(sed -n 's/^version: *\([^+ ]*\).*/\1/p' pubspec.yaml) (expected)"
  package="$app_id (expected)"
fi

# The certificate that signed it: the upload key's, never a debug one.
signed=$("$keytool" -printcert -jarfile "$aab" 2>&1 || true)
signed_owner=$(sed -n 's/^Owner: //p' <<<"$signed" | head -n1)
signed_sha256=$(sed -n 's/^[[:space:]]*SHA256: //p' <<<"$signed" | head -n1)
if [[ -z $signed_sha256 ]]; then
  echo "error: the bundle isn't signed" >&2
  problems=$((problems + 1))
elif [[ $signed_sha256 != "$key_sha256" ]]; then
  echo "error: the bundle is signed by $signed_owner ($signed_sha256), not the upload key" >&2
  problems=$((problems + 1))
fi

echo "dist/Bijou-Play.aab ($(du -h "$aab" | cut -f1))"
echo "  app id:       $package"
echo "  version code: $version_code"
echo "  version name: $version_name"
echo "  upload key:   $owner"
echo "  SHA-256:      $key_sha256"
if ((problems > 0)); then
  echo "$problems problem(s) above: don't upload this bundle." >&2
  exit 1
fi
