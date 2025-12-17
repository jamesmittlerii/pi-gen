#!/bin/bash -e

# Hardened JACK setup for headless / appliance builds.
# - Config-driven device selection via /etc/jack/jack.env
# - Waits for ALSA device (handles USB enumeration timing)
# - Disables JACK audio reservation (avoids dbus/session issues)
# - Sets RT limits
# - Installs systemd service and enables it

# ---- Realtime permissions (JACK) ----
cat > "${ROOTFS_DIR}/etc/security/limits.d/audio.conf" <<'EOF'
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -10
EOF

# Add default user to audio group (pi-gen usually creates 'pi')
on_chroot <<'EOF'
set -e
if getent passwd pi >/dev/null; then
  usermod -aG audio pi || true
fi
EOF

# ---- Config file (easy to change later) ----
install -d -m 0755 "${ROOTFS_DIR}/etc/jack"

cat > "${ROOTFS_DIR}/etc/jack/jack.env" <<'EOF'
# Device selector (change this later if you swap DACs)
# Examples:
#   JACK_DEVICE=hw:CARD=SL
#   JACK_DEVICE=hw:USB
#   JACK_DEVICE=hw:0
JACK_DEVICE=hw:CARD=SL

# Zynthian-proven baseline
JACK_RATE=48000
JACK_PERIOD=128
JACK_NPERIODS=2
JACK_PRIORITY=70

# Optional toggles
JACK_SYNC=1            # 1 => add -S
JACK_ALSA_MIDI=raw     # adds: -X raw (set empty to disable)

# Optional extra flags (if you still want Zynthian's -s, keep it here)
JACK_EXTRA_FLAGS="-s"
EOF
chmod 0644 "${ROOTFS_DIR}/etc/jack/jack.env"

# ---- Wrapper that reads /etc/jack/jack.env ----
cat > "${ROOTFS_DIR}/usr/local/bin/jack-start" <<'EOF'
#!/bin/bash
set -euo pipefail

ENVFILE=/etc/jack/jack.env
[ -f "$ENVFILE" ] && source "$ENVFILE"

: "${JACK_DEVICE:=hw:0}"
: "${JACK_RATE:=48000}"
: "${JACK_PERIOD:=128}"
: "${JACK_NPERIODS:=2}"
: "${JACK_PRIORITY:=70}"
: "${JACK_SYNC:=0}"
: "${JACK_ALSA_MIDI:=raw}"
: "${JACK_EXTRA_FLAGS:=}"

# Avoid dbus/session reservation issues on minimal/headless systems
export JACK_NO_AUDIO_RESERVATION=1

# If JACK_DEVICE is hw:CARD=<NAME>[,...], wait until that ALSA card exists.
card=""
if [[ "${JACK_DEVICE}" =~ ^hw:CARD=([^,]+) ]]; then
  card="${BASH_REMATCH[1]}"
fi

if [ -n "${card}" ]; then
  # Wait up to ~20s for the card to appear (udev/USB timing)
  for i in $(seq 1 80); do
    if grep -qE "^[[:space:]]*[0-9]+[[:space:]]+\\[${card}[[:space:]]*\\]" /proc/asound/cards 2>/dev/null; then
      break
    fi
    sleep 0.25
  done
fi

sync_flag=""
if [ "${JACK_SYNC}" = "1" ]; then
  sync_flag="-S"
fi

midi_flag=""
if [ -n "${JACK_ALSA_MIDI}" ]; then
  midi_flag="-X ${JACK_ALSA_MIDI}"
fi

exec /usr/bin/jackd \
  -P "${JACK_PRIORITY}" \
  ${JACK_EXTRA_FLAGS} \
  ${sync_flag} \
  -d alsa -d "${JACK_DEVICE}" \
  -r "${JACK_RATE}" -p "${JACK_PERIOD}" -n "${JACK_NPERIODS}" \
  ${midi_flag}
EOF
chmod 0755 "${ROOTFS_DIR}/usr/local/bin/jack-start"

# ---- systemd service ----
cat > "${ROOTFS_DIR}/etc/systemd/system/jack.service" <<'EOF'
[Unit]
Description=JACK Audio Daemon (configurable)
After=sound.target
Wants=sound.target

[Service]
Type=simple
User=pi
Group=audio

# Let JACK get realtime + lock memory
LimitRTPRIO=95
LimitMEMLOCK=infinity

# Don’t restart-storm forever if the DAC is unplugged
Restart=on-failure
RestartSec=2
StartLimitIntervalSec=30
StartLimitBurst=5

ExecStart=/usr/local/bin/jack-start

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "${ROOTFS_DIR}/etc/systemd/system/jack.service"

# Enable in the image
on_chroot <<'EOF'
systemctl daemon-reload
systemctl enable jack.service
EOF

