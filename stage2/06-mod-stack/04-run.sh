#!/bin/bash -e

on_chroot <<'EOF'
set -e

# Where we install mod-ui
MODUI_DIR=/opt/mod-ui
MODUI_REPO=https://github.com/mod-audio/mod-ui.git
MODUI_PORT=8888
MODUI_BIND=127.0.0.1

export HOME=/root
export XDG_CACHE_HOME=/root/.cache
export PIP_CACHE_DIR=/tmp/pip-cache

mkdir -p /var/modep/pedalboards

# (Re)install mod-ui repo
rm -rf "$MODUI_DIR"
git clone --depth=1 "$MODUI_REPO" "$MODUI_DIR"

# Python venv (avoids PEP668 "externally-managed-environment")
python3 -m venv "$MODUI_DIR/.venv"
"$MODUI_DIR/.venv/bin/python" -m pip install --upgrade pip wheel setuptools

# Install python deps
# NOTE: this can take a bit, but now that rootfs expands it’s fine.
PIP_DISABLE_PIP_VERSION_CHECK=1 "$MODUI_DIR/.venv/bin/pip" install -r "$MODUI_DIR/requirements.txt"

"$MODUI_DIR/.venv/bin/python" -m pip install -U "pyserial>=3.5"

#

# Patch Tornado 4.3 for Python 3.11+ without importing tornado (import would crash)
HTTPTUTIL="$(ls -1 "$MODUI_DIR"/.venv/lib/python3*/site-packages/tornado/httputil.py | head -n1)"
echo "Patching: $HTTPTUTIL"

if [ -f "$HTTPTUTIL" ]; then
  sed -i 's/collections.MutableMapping/collections.abc.MutableMapping/g' "$HTTPTUTIL"
else
  echo "ERROR: tornado/httputil.py not found in venv" >&2
  exit 1
fi


PATH="$MODUI_DIR/.venv/bin:$PATH" make -C "$MODUI_DIR/utils"

# Ensure mod-ui can write its runtime data as user pi
install -d -m 0755 /opt/mod-ui/data
chown -R pi:pi /opt/mod-ui
chown -R pi:pi /var/modep

# Systemd service (headless controller)
cat >/etc/systemd/system/mod-ui.service <<SERVICE
[Unit]
Description=MOD UI (headless API)
After=network-online.target jack.service mod-host.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$MODUI_DIR
# Bind to localhost only (headless controller; expose via SSH tunnel if needed)
Environment=MOD_UI_HOST=$MODUI_BIND
Environment=MOD_UI_PORT=$MODUI_PORT
ExecStart=$MODUI_DIR/.venv/bin/python $MODUI_DIR/server.py
Restart=on-failure
User=pi
Group=audio

[Install]
WantedBy=multi-user.target
SERVICE

rm -rf /root/.cache/pip
systemctl daemon-reload
systemctl disable mod-ui.service
EOF
