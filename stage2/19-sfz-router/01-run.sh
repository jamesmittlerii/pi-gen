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

# Precompile Python bytecode (best-effort; small startup win)
# -q = quiet; -f = force; run as pi so __pycache__ ownership is sane
echo "[sfz-router] Precompiling python bytecode..."
su -s /bin/bash -c 'python3 -m compileall -q -f /opt/router || true' pi

# Enable service
systemctl daemon-reload
systemctl enable router-loader.service

# Sanity checks (non-fatal)
python3 -c "import jack, mido; print('[sfz-router] python imports OK')" || true
test -f /opt/router/load_single.py
echo "[sfz-router] Installed."

CHROOT_EOF
