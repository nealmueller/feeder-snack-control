#!/bin/zsh
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VENDOR_DIR="$ROOT/VendorPython"
SITE_PACKAGES="$VENDOR_DIR/site-packages"
STAMP_FILE="$VENDOR_DIR/.python-version"
if [ -x /opt/homebrew/bin/python3 ]; then
  PYTHON_BIN="${PYTHON_BIN:-/opt/homebrew/bin/python3}"
else
  PYTHON_BIN="${PYTHON_BIN:-$(command -v python3)}"
fi

if [ -z "${PYTHON_BIN}" ]; then
  echo "python3 is required to prepare the embedded runtime" >&2
  exit 1
fi

PYTHON_PREFIX="$("$PYTHON_BIN" - <<'PY'
import sys
print(sys.base_prefix)
PY
)"
PYTHON_FRAMEWORK="$("$PYTHON_BIN" - <<'PY'
from pathlib import Path
import sys

path = Path(sys.base_prefix)
for candidate in [path, *path.parents]:
    if candidate.name == "Python.framework":
        print(candidate)
        break
else:
    raise SystemExit("Unable to locate Python.framework")
PY
)"
PYTHON_VERSION="$("$PYTHON_BIN" - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
)"

mkdir -p "$SITE_PACKAGES"

if [ ! -f "$STAMP_FILE" ] || [ "$(cat "$STAMP_FILE")" != "$PYTHON_VERSION" ]; then
  rm -rf "$VENDOR_DIR"
  mkdir -p "$SITE_PACKAGES"
fi

if [ ! -f "$SITE_PACKAGES/.prepared" ]; then
  "$PYTHON_BIN" -m pip install \
    --upgrade \
    --no-cache-dir \
    --target "$SITE_PACKAGES" \
    pylitterbot >/dev/null
  echo "$PYTHON_VERSION" > "$STAMP_FILE"
  touch "$SITE_PACKAGES/.prepared"
fi

APP_FRAMEWORKS_DIR="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
APP_RESOURCES_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$APP_FRAMEWORKS_DIR" "$APP_RESOURCES_DIR/VendorPython"

rsync -a --delete \
  "$PYTHON_FRAMEWORK" \
  "$APP_FRAMEWORKS_DIR/"

rsync -a --delete "$SITE_PACKAGES/" "$APP_RESOURCES_DIR/VendorPython/site-packages/"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP_RESOURCES_DIR/AppIcon.icns"
fi
