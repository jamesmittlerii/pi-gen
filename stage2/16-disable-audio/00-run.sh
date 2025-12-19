#!/bin/bash -e

# Disable onboard audio (PWM / bcm2835 audio) and Wi-Fi.
# Works on Bookworm (/boot/firmware/config.txt) and older layouts (/boot/config.txt).

CFG="${ROOTFS_DIR}/boot/firmware/config.txt"
if [ ! -f "$CFG" ]; then
  CFG="${ROOTFS_DIR}/boot/config.txt"
fi

# If neither exists, just exit cleanly
if [ ! -f "$CFG" ]; then
  echo "WARN: config.txt not found (looked in /boot/firmware and /boot). Skipping disable-audio/disable-wifi."
  exit 0
fi

append_overlay() {
  local overlay="$1"
  local comment="$2"

  if grep -Eq "^\s*dtoverlay\s*=\s*${overlay}\s*$" "$CFG"; then
    echo "INFO: dtoverlay=${overlay} already present in $CFG"
    return
  fi

  cat >> "$CFG" <<EOF

# ${comment}
dtoverlay=${overlay}
EOF

  echo "INFO: Added dtoverlay=${overlay} to $CFG"
}

# Disable onboard audio (external DAC in use)
append_overlay "disable-audio" "Disable onboard audio (using external DAC)"

# Disable onboard Wi-Fi (headless / wired-only system)
append_overlay "disable-wifi" "Disable onboard Wi-Fi (not used)"
