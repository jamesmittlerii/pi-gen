#!/bin/bash -e

on_chroot <<'EOF'
set -e

# Disable the first-boot interactive user configuration dialog.
systemctl disable userconfig.service 2>/dev/null || true
systemctl mask userconfig.service 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true

# userconf-pi / rename-user leaves an sshd Banner drop-in behind if userconfig never runs.
# Remove it so SSH logins don't show the "SSH may not work..." warning forever.
rm -f /etc/ssh/sshd_config.d/rename_user.conf

# (Optional hard override; use if something else re-adds a Banner later)
# cat >/etc/ssh/sshd_config.d/99-no-banner.conf <<'EOM'
# Banner none
# EOM
EOF
