#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
APP_PATH="$SCRIPT_DIR/OldPad Sidecar.app"
CONTENTS_PATH="$APP_PATH/Contents"
EXECUTABLE_PATH="$CONTENTS_PATH/MacOS/OldPad Sidecar"

mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$SCRIPT_DIR/app/Info.plist" "$CONTENTS_PATH/Info.plist"

xcrun clang \
  -arch arm64 \
  -fobjc-arc \
  -fblocks \
  -Wall \
  -Wextra \
  -framework AppKit \
  -framework Foundation \
  "$SCRIPT_DIR/app/OldPadSidecar.m" \
  -o "$EXECUTABLE_PATH"

codesign --force --deep --sign - "$APP_PATH"
echo "완료: $APP_PATH"
