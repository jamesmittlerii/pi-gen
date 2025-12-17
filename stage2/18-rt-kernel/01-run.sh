#!/bin/bash -e

# Ensure the RT kernel is selected at boot
# pi-gen images typically use /boot/firmware/config.txt
CFG="${ROOTFS_DIR}/boot/firmware/config.txt"

# Be defensive if file layout differs
if [ ! -f "$CFG" ] && [ -f "${ROOTFS_DIR}/boot/config.txt" ]; then
  CFG="${ROOTFS_DIR}/boot/config.txt"
fi

# Append only if not already present
grep -q '^kernel=kernel8_rt\.img' "$CFG" || cat >> "$CFG" <<'CONF'

# --- PREEMPT_RT kernel selection ---
kernel=kernel8_rt.img
arm_64bit=1

# Optional debug / sanity during early testing:
enable_uart=1
uart_2ndstage=1
dtoverlay=disable-bt
CONF
