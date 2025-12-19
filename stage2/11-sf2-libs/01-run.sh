#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

BASE=/usr/local/share/sf2
PIANOS="$BASE/pianos"
EPIANOS="$BASE/epianos"

install -d -m 0755 "$PIANOS" "$EPIANOS"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

clone_fresh() {
  # clone_fresh <url> <dest>
  local url="$1"
  local dest="$2"
  rm -rf "$dest"
  git clone --depth=1 "$url" "$dest"
}

rsync_dir() {
  # rsync_dir <src_dir/> <dst_dir/>
  local src="$1"
  local dst="$2"
  install -d -m 0755 "$dst"
  rsync -a --delete "$src" "$dst"
  chmod -R a+rX "$dst"
}

download() {
  # download <url> <outfile>
  local url="$1"
  local out="$2"
  rm -f "$out"
  mkdir -p "$(dirname "$out")"
  curl -L --fail -o "$out" "$url"
}

flatten_if_single_dir() {
  # If dir contains exactly one subdir and no other files, move contents up one level
  local dir="$1"

  # count entries
  local entries
  entries="$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  if [ "$entries" != "1" ]; then
    return 0
  fi

  local only
  only="$(find "$dir" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
  if [ -z "$only" ]; then
    return 0
  fi

  echo "Flattening single nested directory: $only -> $dir"
  local tmp="$dir/.tmp_flatten"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  cp -a "$only/." "$tmp/"
  rm -rf "$only"
  cp -a "$tmp/." "$dir/"
  rm -rf "$tmp"
}

extract_tar_xz_to() {
  # extract_tar_xz_to <tar.xz> <dest_dir>
  local tarfile="$1"
  local dest="$2"
  rm -rf "$dest"
  install -d -m 0755 "$dest"
  tar -xJf "$tarfile" -C "$dest"
  flatten_if_single_dir "$dest"
  chmod -R a+rX "$dest"
}

extract_zip_to() {
  # extract_zip_to <zip> <dest_dir>
  local zipfile="$1"
  local dest="$2"
  rm -rf "$dest"
  install -d -m 0755 "$dest"
  unzip -q "$zipfile" -d "$dest"
  chmod -R a+rX "$dest"
}

# Merge all <control> blocks into one at the top, enforcing default_path and prefix_sfz_path.
# fix_control_block <sfz_path> <default_path_value> <prefix_value>
fix_control_block() {
  local sfz="$1"
  local defpath="$2"
  local prefix="$3"

  [ -f "$sfz" ] || { echo "WARN: missing $sfz"; return 0; }

  local tmp
  tmp="$(mktemp)"

  awk -v defpath="$defpath" -v prefix="$prefix" '
    BEGIN { inctl=0; nctl=0; nb=0 }

    /^[[:space:]]*<control>[[:space:]]*$/ { inctl=1; next }

    inctl {
      if ($0 ~ /^[[:space:]]*$/) { inctl=0; next }
      if ($0 ~ /^[[:space:]]*default_path[[:space:]]*=/) next
      if ($0 ~ /^[[:space:]]*prefix_sfz_path[[:space:]]*=/) next

      key=$0
      if (!(key in seen)) { seen[key]=1; ctl[++nctl]=$0 }
      next
    }

    { body[++nb]=$0 }

    END {
      print "<control>"
      print "default_path=" defpath
      for (i=1; i<=nctl; i++) {
        if (ctl[i] ~ /^[[:space:]]*$/) continue
        print ctl[i]
      }
      print "prefix_sfz_path=" prefix
      print ""
      for (i=1; i<=nb; i++) print body[i]
    }
  ' "$sfz" > "$tmp"

  install -m 0644 "$tmp" "$sfz"
  rm -f "$tmp"
}

# ------------------------------------------------------------------------------
# Working area (will be deleted at end)
# ------------------------------------------------------------------------------
WORK=/tmp/sf2-libs
rm -rf "$WORK"
mkdir -p "$WORK"

# ------------------------------------------------------------------------------
# PIANOS
# ------------------------------------------------------------------------------

CLAV_SF2="$EPIANOS/Clavinet/Clavinet_Lit.sf2"
download \
  https://musical-artifacts.com/artifacts/2347/Clavinet_Lit.sf2 "$CLAV_SF2"


# ------------------------------------------------------------------------------
# Cleanup: remove any git metadata, sources, and temp workdir
# ------------------------------------------------------------------------------
find "$BASE" -type d -name .git -prune -exec rm -rf {} + || true
rm -rf "$EPIANOS/_sources" || true
rm -rf "$WORK" || true

# ------------------------------------------------------------------------------
# Index SFZ entrypoints
# ------------------------------------------------------------------------------
find "$BASE" -type f -name '*.sf2' | sort > "$BASE/index.txt"
chmod 0644 "$BASE/index.txt"

EOF
