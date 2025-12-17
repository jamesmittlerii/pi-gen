#!/bin/bash -e

on_chroot <<'CHROOT_EOF'
set -euo pipefail

echo "[gxwah] Installing GxSwitchlessWah.lv2 build deps already handled by 00-packages"

SRC_BASE=/usr/src
REPO_URL=https://github.com/brummer10/GxSwitchlessWah.lv2.git
REPO_DIR="$SRC_BASE/GxSwitchlessWah.lv2"

mkdir -p "$SRC_BASE"
rm -rf "$REPO_DIR"

cd "$SRC_BASE"
git clone --depth=1 "$REPO_URL"
cd "$REPO_DIR"

make -j"$(nproc)"
make install

# ensure LV2 cache/paths aren't stale (harmless if not needed)
ldconfig || true

# Sanity checks (non-fatal)
if command -v lv2ls >/dev/null 2>&1; then
  echo "[gxwah] lv2ls contains switchless wah?"
  lv2ls | grep -i "gx_switchless_wah" || true
  lv2ls | grep -i "wah" || true
fi

echo "[gxwah] Installed. Bundles:"
ls -la /usr/local/lib/lv2 2>/dev/null | grep -i wah || true
ls -la /usr/lib/lv2       2>/dev/null | grep -i wah || true

CHROOT_EOF
