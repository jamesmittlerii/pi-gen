#!/bin/bash -e

on_chroot <<'EOF'
set -e

# Where we install mod-ui
MODUI_DIR=/opt/mod-ui
MODUI_REPO=https://github.com/mod-audio/mod-ui.git
MODUI_PORT=8888
MODUI_BIND=127.0.0.1

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

# Systemd service (headless controller)
cat >/etc/systemd/system/mod-ui.service <<SERVICE
[Unit]
Description=MOD UI (headless API)
After=network.target

[Service]
Type=simple
WorkingDirectory=$MODUI_DIR
# Bind to localhost only (headless controller; expose via SSH tunnel if needed)
Environment=MOD_UI_HOST=$MODUI_BIND
Environment=MOD_UI_PORT=$MODUI_PORT
ExecStart=$MODUI_DIR/.venv/bin/python $MODUI_DIR/mod-ui
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable mod-ui.service
EOF
