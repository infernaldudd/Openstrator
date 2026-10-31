#!/bin/zsh
# Native Openstrator V6 M6 — Intel one-click builder.
# Apple Command Line Tools are sufficient; no Xcode GUI required.
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
ARCH="x86_64"
LABEL="Intel"
LOG="$ROOT/OPENSTRATOR_BUILD_LOG.txt"
TMP="$ROOT/.openstrator-build-work"
OUT="$ROOT/Build Output"
FINAL="$OUT/Openstrator.app"
STAGED="$TMP/Openstrator.app"

exec > >(tee "$LOG") 2>&1

finish() {
  local exit_code="$1"
  echo
  echo "========================================================="
  if [[ "$exit_code" -eq 0 ]]; then
    echo "SUCCESS: Openstrator V6 M6 has been packaged for $ARCH."
    echo "App: $FINAL"
    echo "Openstrator.app is locally ad-hoc signed, NOT notarized."
    open -R "$FINAL" >/dev/null 2>&1 || true
  else
    echo "BUILD FAILED (exit $exit_code)."
    echo "Read/send this full log: $LOG"
    echo "No empty Build Output folder is created by a failed build."
    if [[ -d "$FINAL" ]]; then
      echo "An earlier successfully built app was preserved at $FINAL"
    fi
  fi
  echo "========================================================="
  echo
  if [[ -t 0 ]]; then
    echo "Press Return to close Terminal."
    read -r reply
  fi
  exit "$exit_code"
}

printf 'Openstrator V6 M6 — %s Terminal builder\n' "$LABEL"
printf 'Target: %s | This Mac: %s\n' "$ARCH" "$(uname -m)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Requires macOS; an .app cannot be built by this script on Linux/Windows.'
  finish 10
fi

# Never delete an existing working .app until its replacement is built.
rm -rf "$TMP"
if ! command -v xcrun >/dev/null 2>&1; then
  echo 'Apple Command Line Tools are missing. Install them when prompted and rerun this file.'
  xcode-select --install || true
  finish 11
fi
SWIFT="$(xcrun --find swift 2>/dev/null || true)"
if [[ -z "$SWIFT" || ! -x "$SWIFT" ]]; then
  echo 'Swift compiler not found. Install Apple Command Line Tools or Xcode.'
  xcode-select --install || true
  finish 12
fi
if [[ ! -f "$ROOT/Package.swift" || ! -f "$ROOT/Resources/Openstrator.icns" ]]; then
  echo 'Project files are missing. Fully extract the ZIP before running this script.'
  finish 13
fi
"$SWIFT" --version

mkdir -p "$TMP"
echo '[1/5] Build and run framework-free V6 core self-test…'
SELFTEST_BUILD="$TMP/selftest"
if ! "$SWIFT" build \
  --package-path "$ROOT" \
  --build-path "$SELFTEST_BUILD" \
  --configuration release \
  --arch "$ARCH" \
  --product OpenstratorCoreSelfTest; then
  echo 'Core self-test compilation failed. Check the FIRST error above in the log.'
  rm -rf "$TMP"
  finish 19
fi
SELFTEST_BIN="$(find "$SELFTEST_BUILD" -type f -name OpenstratorCoreSelfTest -path '*release*' -perm -111 -print -quit 2>/dev/null)"
if [[ -z "$SELFTEST_BIN" || ! -x "$SELFTEST_BIN" ]]; then
  echo 'SwiftPM did not produce the core self-test executable.'
  rm -rf "$TMP"
  finish 19
fi
if ! "$SELFTEST_BIN"; then
  echo 'Core self-test failed. Openstrator.app was not packaged.'
  rm -rf "$TMP"
  finish 19
fi

echo '[2/5] Compile native SwiftUI sources with Swift Package Manager…'
if ! "$SWIFT" build \
  --package-path "$ROOT" \
  --build-path "$TMP/swiftpm" \
  --configuration release \
  --arch "$ARCH" \
  --product Openstrator; then
  echo 'Swift compilation failed. Check the FIRST error above in the log.'
  rm -rf "$TMP"
  finish 20
fi

BIN="$(find "$TMP/swiftpm" -type f -name Openstrator -path '*release*' -perm -111 -print -quit 2>/dev/null)"
if [[ -z "$BIN" || ! -f "$BIN" ]]; then
  echo 'SwiftPM did not produce an Openstrator executable.'
  rm -rf "$TMP"
  finish 21
fi

echo '[3/5] Verify architecture before packaging…'
if ! command -v lipo >/dev/null 2>&1; then
  echo 'The Apple lipo tool is missing.'
  rm -rf "$TMP"
  finish 22
fi
ACTUAL="$(lipo -archs "$BIN" 2>/dev/null || true)"
if [[ "$ACTUAL" != "$ARCH" ]]; then
  echo "Incorrect executable architecture: expected $ARCH, got '$ACTUAL'."
  rm -rf "$TMP"
  finish 23
fi

# Copy the icon and mark into the app's resource directory. SwiftPM does
# not compile Xcode .xcassets, so the standalone PNG is required as well.
echo '[4/5] Create Openstrator.app and ad-hoc sign it…'
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
cp "$BIN" "$STAGED/Contents/MacOS/Openstrator" || finish 24
chmod 755 "$STAGED/Contents/MacOS/Openstrator"
cp "$ROOT/Openstrator/Info.plist" "$STAGED/Contents/Info.plist" || finish 24
cp "$ROOT/Resources/Openstrator.icns" "$STAGED/Contents/Resources/Openstrator.icns" || finish 24
cp "$ROOT/Resources/OpenstratorMark.png" "$STAGED/Contents/Resources/OpenstratorMark.png" || finish 24
PB='/usr/libexec/PlistBuddy'
"$PB" -c 'Add :CFBundleExecutable string Openstrator' "$STAGED/Contents/Info.plist" 2>/dev/null || \
  "$PB" -c 'Set :CFBundleExecutable Openstrator' "$STAGED/Contents/Info.plist" || finish 25
"$PB" -c 'Add :CFBundlePackageType string APPL' "$STAGED/Contents/Info.plist" 2>/dev/null || \
  "$PB" -c 'Set :CFBundlePackageType APPL' "$STAGED/Contents/Info.plist" || finish 25
"$PB" -c 'Add :CFBundleIconFile string Openstrator.icns' "$STAGED/Contents/Info.plist" 2>/dev/null || \
  "$PB" -c 'Set :CFBundleIconFile Openstrator.icns' "$STAGED/Contents/Info.plist" || finish 25
"$PB" -c 'Add :NSPrincipalClass string NSApplication' "$STAGED/Contents/Info.plist" 2>/dev/null || \
  "$PB" -c 'Set :NSPrincipalClass NSApplication' "$STAGED/Contents/Info.plist" || finish 25
if ! codesign --force --sign - "$STAGED"; then
  echo 'Local ad-hoc code signing failed.'
  rm -rf "$TMP"
  finish 26
fi
if ! codesign --verify "$STAGED"; then
  echo 'Code signature verification failed.'
  rm -rf "$TMP"
  finish 27
fi

# Publish only after compile, architecture and signature have succeeded.
echo '[5/5] Verify app and publish to Build Output…'
if [[ ! -x "$STAGED/Contents/MacOS/Openstrator" ]]; then
  echo 'Missing app executable.'
  rm -rf "$TMP"
  finish 28
fi
mkdir -p "$OUT"
if [[ -e "$FINAL" ]]; then
  rm -rf "$FINAL"
fi
if ! mv "$STAGED" "$FINAL"; then
  echo 'Unable to move the app into Build Output.'
  rm -rf "$TMP"
  finish 29
fi
rm -rf "$TMP"
finish 0
