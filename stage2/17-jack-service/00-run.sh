#!/bin/bash -e

# Hardened JACK setup for headless / appliance builds.
# - Defaults via /etc/default/jack (installed from stage files/)
# - systemd service installed from stage files/jack.service
# - jack-start wrapper reads env vars passed by systemd (no implicit sourcing)
# - Waits for ALSA card (USB enumeration timing)
# - Disables JACK audio reservation
# - Sets RT limits
# - Enables jack.service

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

# Resolve this sub-stage directory reliably (works even if STAGE_DIR points at stage2)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# --- Copy stage files into the target filesystem (host side, not chroot) ---
install -d -m 0755 "${ROOTFS_DIR}/etc/default"
install -m 0644 "${SCRIPT_DIR}/files/jack.default" \
  "${ROOTFS_DIR}/etc/default/jack"


install -d -m 0755 "${ROOTFS_DIR}/etc/systemd/system"
install -m 0644 "${SCRIPT_DIR}/files/jack.service" \
  "${ROOTFS_DIR}/etc/systemd/system/jack.service"

# ---- jack-start wrapper (no config-file sourcing; systemd provides env) ----
cat > "${ROOTFS_DIR}/usr/local/bin/jack-start" <<'EOF'
#!/bin/bash
set -euo pipefail

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

# ---- Enable in the image ----
on_chroot <<'EOF'
systemctl daemon-reload
systemctl enable jack.service
EOF
