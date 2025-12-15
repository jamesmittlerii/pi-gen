#!/bin/bash -e

# Disable onboard audio (PWM / bcm2835 audio) since we're using an external DAC.
# Works on Bookworm (/boot/firmware/config.txt) and older layouts (/boot/config.txt).

CFG="${ROOTFS_DIR}/boot/firmware/config.txt"
if [ ! -f "$CFG" ]; then
  CFG="${ROOTFS_DIR}/boot/config.txt"
fi

# If neither exists, just exit cleanly
if [ ! -f "$CFG" ]; then
  echo "WARN: config.txt not found (looked in /boot/firmware and /boot). Skipping disable-audio."
  exit 0
fi

# Don’t add duplicates
if grep -Eq '^\s*dtoverlay\s*=\s*disable-audio\s*$' "$CFG"; then
  echo "INFO: dtoverlay=disable-audio already present in $CFG"
  exit 0
fi

cat >> "$CFG" <<'EOF'

# Disable onboard audio (using external DAC)
dtoverlay=disable-audio
EOF

echo "INFO: Added dtoverlay=disable-audio to $CFG"

