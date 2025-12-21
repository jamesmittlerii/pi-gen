#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

cd /usr/src

# Fresh clone
rm -rf GxSwitchlessWah.lv2
git clone --depth=1 https://github.com/brummer10/GxSwitchlessWah.lv2.git
cd GxSwitchlessWah.lv2

make -j"$(nproc)"
make install

# sanity check (non-fatal)
test -d /usr/lib/lv2/GxSwitchlessWah.lv2 || \
test -d /usr/local/lib/lv2/GxSwitchlessWah.lv2 || true

# cleanup build tree
cd / && rm -rf /usr/src/GxSwitchlessWah.lv2
EOF
