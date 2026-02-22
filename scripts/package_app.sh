#!/usr/bin/env bash
set -euo pipefail

APP_NAME="InputAutoSwitcher"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf dist
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

BIN_PATH="$(swift build -c release --show-bin-path)"
if [[ ! -f "${BIN_PATH}/${APP_NAME}" ]]; then
  echo "Missing binary: ${BIN_PATH}/${APP_NAME}" >&2
  exit 1
fi

cp "${BIN_PATH}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>InputAutoSwitcher</string>
  <key>CFBundleExecutable</key>
  <string>InputAutoSwitcher</string>
  <key>CFBundleIdentifier</key>
  <string>com.songzihan.inputautoswitcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>InputAutoSwitcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Used to observe active applications and switch input source.</string>
</dict>
</plist>
PLIST

echo "Packaged app at ${APP_DIR}"
