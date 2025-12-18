#!/bin/bash -e

on_chroot <<'CHROOT_EOF'
set -euo pipefail

echo "[x42] Installing x42 midi filter.lv2 build deps already handled by 00-packages"

SRC_BASE=/usr/src
REPO_URL=https://github.com/x42/midifilter.lv2.git
REPO_DIR="$SRC_BASE/midifilter.lv2"

mkdir -p "$SRC_BASE"
rm -rf "$REPO_DIR"

cd "$SRC_BASE"
git clone --depth=1 "$REPO_URL"
cd "$REPO_DIR"

make -j"$(nproc)"
make install PREFIX=/usr

# ensure LV2 cache/paths aren't stale (harmless if not needed)
ldconfig || true

# Sanity checks (non-fatal)
if command -v lv2ls >/dev/null 2>&1; then
  echo "[midifilter] lv2ls contains eventblocker?"
  lv2ls | grep -i "eventblocker" || true
fi

echo "[midifilter] Installed. Bundles:"
ls -la /usr/local/lib/lv2 2>/dev/null | grep -i eventblocker || true
ls -la /usr/lib/lv2       2>/dev/null | grep -i eventblocker || true

CHROOT_EOF
