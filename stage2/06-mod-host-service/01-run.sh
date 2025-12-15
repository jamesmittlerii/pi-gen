#!/bin/bash -e

# Copy files from this stage into the target rootfs (host-side)
install -D -m 0644 files/mod-host.service \
  "${ROOTFS_DIR}/etc/systemd/system/mod-host.service"

install -D -m 0755 files/mod-host-init.sh \
  "${ROOTFS_DIR}/usr/local/bin/mod-host-init.sh"

# Enable service inside the image (chroot-side)
on_chroot <<'EOF'
set -e
systemctl daemon-reload
systemctl enable mod-host.service
EOF
