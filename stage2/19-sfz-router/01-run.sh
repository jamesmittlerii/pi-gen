#!/bin/bash -e

# Resolve this sub-stage directory reliably (works even if STAGE_DIR points at stage2)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# --- Copy stage files into the target filesystem (host side, not chroot) ---
install -d -m 0755 "${ROOTFS_DIR}/etc/default"
install -m 0644 "${SCRIPT_DIR}/files/router-loader.default" \
  "${ROOTFS_DIR}/etc/default/router-loader"

install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system"
install -m 0644 "${SCRIPT_DIR}/files/router-loader.service" \
  "${ROOTFS_DIR}/etc/systemd/system/router-loader.service"

# --- Now do the rest inside the chroot ---
on_chroot <<'CHROOT_EOF'
set -euo pipefail

echo "[sfz-router] Installing router repo to /opt/router"

# Clone repo
install -d -m 0755 /opt
rm -rf /opt/router
git clone --depth=1 https://github.com/jamesmittlerii/router.git /opt/router

# Ensure pi owns it (so edits/tests as pi are easy)
chown -R pi:pi /opt/router

# Enable service
systemctl daemon-reload
systemctl enable router-loader.service

# Sanity checks (non-fatal)
python3 -c "import jack, mido; print('[sfz-router] python imports OK')" || true
test -f /opt/router/load_single.py
echo "[sfz-router] Installed."

CHROOT_EOF

