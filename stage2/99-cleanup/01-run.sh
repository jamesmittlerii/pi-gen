#!/bin/bash -e

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
