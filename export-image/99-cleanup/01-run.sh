#!/bin/bash -e

# Ensure chroot mountpoints exist (export-image rootfs is a fresh tree)
install -d -m 0755 "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev" "${ROOTFS_DIR}/dev/pts" "${ROOTFS_DIR}/run"

on_chroot <<'EOF'
set -euo pipefail

echo "[cleanup] apt caches"
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[cleanup] temp + caches"
rm -rf /tmp/*
rm -rf /var/tmp/*
rm -rf /root/.cache
EOF
