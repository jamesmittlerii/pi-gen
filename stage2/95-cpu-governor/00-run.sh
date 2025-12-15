#!/bin/bash -e

# ---- Force CPU governor to performance (persistent) ----

# cpufrequtils config
cat > "${ROOTFS_DIR}/etc/default/cpufrequtils" <<'EOF'
ENABLE="true"
GOVERNOR="performance"
MAX_SPEED="0"
MIN_SPEED="0"
EOF

# Enable service in image
on_chroot <<'EOF'
systemctl enable cpufrequtils
EOF

