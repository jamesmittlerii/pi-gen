#!/bin/bash -e

# Host-side git info
PG_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
PG_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)


on_chroot <<EOF
cat >/etc/pi-gen-build <<EOM
BUILD_NAME=${IMG_NAME:-custom-pi-gen}
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_BRANCH=$(cd /pi-gen && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
GIT_COMMIT=$(cd /pi-gen && git rev-parse --short HEAD 2>/dev/null || echo unknown)
EOM
EOF
