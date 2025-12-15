#!/bin/bash -e

on_chroot <<'EOF'
set -e

# Disable the first-boot interactive user configuration dialog.
# We provision users/ssh via pi-gen, so this is redundant for headless images.
systemctl disable userconfig.service 2>/dev/null || true
systemctl mask userconfig.service 2>/dev/null || true

# If a previous boot marked it failed, clear failure state (harmless at build time)
systemctl reset-failed 2>/dev/null || true
EOF

