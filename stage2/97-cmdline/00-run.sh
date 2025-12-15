#!/bin/bash -e

CMD="${ROOTFS_DIR}/boot/firmware/cmdline.txt"

# Append only if missing
grep -q 'threadirqs' "$CMD" || \
  sed -i 's/$/ threadirqs/' "$CMD"

