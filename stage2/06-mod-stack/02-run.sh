#!/bin/bash -e

on_chroot <<'EOF'
set -e

cd /usr/src
rm -rf mod-host
git clone --depth=1 https://github.com/moddevices/mod-host.git
cd mod-host

make -j"$(nproc)"
make install
ldconfig || true

# sanity
command -v mod-host >/dev/null
mod-host -h >/dev/null 2>&1 || true

# cleanup build tree
cd / && rm -rf /usr/src/mod-host

# Show LV2 inventory size (useful for debugging)
if command -v lv2ls >/dev/null; then
  lv2ls | head -n 5 || true
fi
EOF
