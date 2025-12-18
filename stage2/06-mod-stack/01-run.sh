#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

SRC=/usr/src/mod-utilities
LV2_DIR=/usr/lib/lv2

# Idempotent rebuilds
rm -rf "$SRC"
mkdir -p /usr/src
cd /usr/src

git clone --depth=1 https://github.com/mod-audio/mod-utilities.git
cd mod-utilities

# Build + install all plugins (repo default is /usr/local/lib/lv2 unless overridden)
make -j"$(nproc)"
make install INSTALL_PATH="$LV2_DIR"

# Sanity check: confirm Gain2x2 (and friends) are now visible to LV2 registry
if command -v lv2ls >/dev/null 2>&1; then
  echo "LV2 sanity check:"
  lv2ls | grep -i -E 'moddevices|Gain2x2|Gain' || true
fi

# Optional: nuke build tree to save image space
cd /
rm -rf "$SRC"
EOF
