#!/bin/bash
# Claude Code on the web 用: Flutter SDK を入れて flutter analyze / flutter test を使える状態にする。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# CI と同じバージョンを使う（.github/workflows/ci.yml の flutter-version に追従）
FLUTTER_VERSION="$(grep -m1 -oP 'flutter-version:\s*\K[0-9.]+' .github/workflows/ci.yml)"
FLUTTER_DIR=/opt/flutter

if [ ! -x "$FLUTTER_DIR/bin/flutter" ] || ! "$FLUTTER_DIR/bin/flutter" --version 2>/dev/null | grep -q "Flutter $FLUTTER_VERSION "; then
  rm -rf "$FLUTTER_DIR"
  tmp="$(mktemp -d)"
  curl -sSfL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf "$tmp/flutter.tar.xz" -C /opt
  rm -rf "$tmp"
fi

git config --global --get-all safe.directory | grep -qx "$FLUTTER_DIR" \
  || git config --global --add safe.directory "$FLUTTER_DIR"

export PATH="$FLUTTER_DIR/bin:$PATH"
echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

flutter --disable-analytics >/dev/null 2>&1 || true
flutter pub get
