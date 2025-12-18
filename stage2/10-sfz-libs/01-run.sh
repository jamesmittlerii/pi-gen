#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

BASE=/usr/local/share/sfz
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
WORK=/tmp/sfz-libs
rm -rf "$WORK"
mkdir -p "$WORK"

# ------------------------------------------------------------------------------
# PIANOS
# ------------------------------------------------------------------------------

# Salamander (clone -> copy to final without .git)
clone_fresh \
  https://github.com/sfzinstruments/SalamanderGrandPiano.git \
  "$WORK/SalamanderGrandPiano"
rm -rf "$WORK/SalamanderGrandPiano/.git"
rsync_dir "$WORK/SalamanderGrandPiano/" "$PIANOS/SalamanderGrandPiano/"

# K18 (clone -> copy to final without .git)
clone_fresh \
  https://github.com/jamesmittlerii/K18.git \
  "$WORK/K18-Upright-Piano"
rm -rf "$WORK/K18-Upright-Piano/.git"
rsync_dir "$WORK/K18-Upright-Piano/" "$PIANOS/K18-Upright-Piano/"

# K18 Upright (tar.xz)
#K18_TAR="$WORK/K18-Upright-Piano.tar.xz"
#download \
#  https://archive.org/download/K18UprightPiano/K18-Upright-Piano.tar.xz \
#  "$K18_TAR"

#extract_tar_xz_to "$K18_TAR" "$PIANOS/K18-Upright-Piano"

# Ensure SFZ is at library root (some archives vary)
#k18root="$PIANOS/K18-Upright-Piano"
#sfz_found="$(find "$k18root" -maxdepth 4 -type f -iname '*.sfz' | head -n 1 || true)"
#if [ -z "$sfz_found" ]; then
#  echo "WARN: No .sfz found in K18-Upright-Piano (archive may be samples-only?)"
#else
#  if [ "$(dirname "$sfz_found")" != "$k18root" ]; then
#    cp -a "$sfz_found" "$k18root/"
#  fi
#fi
#chmod -R a+rX "$k18root"

# ------------------------------------------------------------------------------
# E-PIANOS: GregSullivan.E-Pianos (CP80, Pianet T, Wurlitzer EP200)
# ------------------------------------------------------------------------------

clone_fresh \
  https://github.com/sfzinstruments/GregSullivan.E-Pianos \
  "$WORK/GregSullivan.E-Pianos"
rm -rf "$WORK/GregSullivan.E-Pianos/.git"

for d in "CP80" "Pianet T" "Wurlitzer EP200"; do
  if [ -d "$WORK/GregSullivan.E-Pianos/$d" ]; then
    rsync_dir "$WORK/GregSullivan.E-Pianos/$d/" "$EPIANOS/$d/"
  else
    echo "WARN: expected dir missing in GregSullivan repo: $d"
  fi
done

# ------------------------------------------------------------------------------
# E-PIANOS: Wurlitzer.zip (Musical Artifacts)
# ------------------------------------------------------------------------------

# Wurlitzer (clone -> copy to final without .git)
clone_fresh \
  https://github.com/jamesmittlerii/Wurlitzer.git \
  "$WORK/Wurlitzer"
rm -rf "$WORK/Wurlitzer/.git"
rsync_dir "$WORK/Wurlitzer/" "$PIANOS/Wurlitzer/"

#WURL_ZIP="$WORK/Wurlitzer.zip"
#download \
#  https://musical-artifacts.com/artifacts/645/Wurlitzer.zip \
#  "$WURL_ZIP"

#extract_zip_to "$WURL_ZIP" "$EPIANOS/Wurlitzer"
# Remove macOS metadata
#rm -rf "$EPIANOS/Wurlitzer/__MACOSX" || true
# Flatten if nested folder named Wurlitzer exists
#if [ -d "$EPIANOS/Wurlitzer/Wurlitzer" ]; then
#  echo "Flattening nested Wurlitzer directory"
#  tmp="$EPIANOS/Wurlitzer/.tmp_flatten"
#  rm -rf "$tmp"
#  mkdir -p "$tmp"
#  cp -a "$EPIANOS/Wurlitzer/Wurlitzer/." "$tmp/"
#  rm -rf "$EPIANOS/Wurlitzer/Wurlitzer"
#  cp -a "$tmp/." "$EPIANOS/Wurlitzer/"
#  rm -rf "$tmp"
#fi
#chmod -R a+rX "$EPIANOS/Wurlitzer"

# ------------------------------------------------------------------------------
# E-PIANOS: jlearman.jRhodes3d
# Layout:
#   epianos/_shared/jRhodes3d/jRhodes3d-{mono,st,sv}/  (samples)
#   epianos/JRhodes3d-*/  (6 preset folders, each has its sfz)
# SFZ patch:
#   one <control> block w/ default_path + prefix_sfz_path + merged control lines
# ------------------------------------------------------------------------------

clone_fresh \
  https://github.com/sfzinstruments/jlearman.jRhodes3d \
  "$WORK/jlearman.jRhodes3d"
rm -rf "$WORK/jlearman.jRhodes3d/.git"

# Shared samples
JR_SHARED="$EPIANOS/_shared/jRhodes3d"
rm -rf "$JR_SHARED"
install -d -m 0755 "$JR_SHARED"

for stem in jRhodes3d-mono jRhodes3d-st jRhodes3d-sv; do
  if [ -d "$WORK/jlearman.jRhodes3d/$stem" ]; then
    rsync_dir "$WORK/jlearman.jRhodes3d/$stem/" "$JR_SHARED/$stem/"
  else
    echo "WARN: missing rhodes samples dir: $stem"
  fi
done

# Preset folders (6)
install -d -m 0755 \
  "$EPIANOS/JRhodes3d-mono" \
  "$EPIANOS/JRhodes3d-mono-no-xfade" \
  "$EPIANOS/JRhodes3d-st" \
  "$EPIANOS/JRhodes3d-st-no-xfade" \
  "$EPIANOS/JRhodes3d-sv" \
  "$EPIANOS/JRhodes3d-sv-no-xfade"

# Copy SFZs into their preset folders
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-mono.sfz"          "$EPIANOS/JRhodes3d-mono/"
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-mono-no-xfade.sfz" "$EPIANOS/JRhodes3d-mono-no-xfade/"
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-st.sfz"            "$EPIANOS/JRhodes3d-st/"
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-st-no-xfade.sfz"   "$EPIANOS/JRhodes3d-st-no-xfade/"
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-sv.sfz"            "$EPIANOS/JRhodes3d-sv/"
cp -a "$WORK/jlearman.jRhodes3d/jRhodes3d-sv-no-xfade.sfz"   "$EPIANOS/JRhodes3d-sv-no-xfade/"

chmod -R a+rX \
  "$EPIANOS/JRhodes3d-mono" \
  "$EPIANOS/JRhodes3d-mono-no-xfade" \
  "$EPIANOS/JRhodes3d-st" \
  "$EPIANOS/JRhodes3d-st-no-xfade" \
  "$EPIANOS/JRhodes3d-sv" \
  "$EPIANOS/JRhodes3d-sv-no-xfade"

# Patch all 6 SFZs: default_path points to shared samples, prefix_sfz_path matches stem/
fix_control_block \
  "$EPIANOS/JRhodes3d-mono/jRhodes3d-mono.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-mono/" \
  "jRhodes3d-mono/"

fix_control_block \
  "$EPIANOS/JRhodes3d-mono-no-xfade/jRhodes3d-mono-no-xfade.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-mono/" \
  "jRhodes3d-mono/"

fix_control_block \
  "$EPIANOS/JRhodes3d-st/jRhodes3d-st.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-st/" \
  "jRhodes3d-st/"

fix_control_block \
  "$EPIANOS/JRhodes3d-st-no-xfade/jRhodes3d-st-no-xfade.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-st/" \
  "jRhodes3d-st/"

fix_control_block \
  "$EPIANOS/JRhodes3d-sv/jRhodes3d-sv.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-sv/" \
  "jRhodes3d-sv/"

fix_control_block \
  "$EPIANOS/JRhodes3d-sv-no-xfade/jRhodes3d-sv-no-xfade.sfz" \
  "../_shared/jRhodes3d/jRhodes3d-sv/" \
  "jRhodes3d-sv/"

# ------------------------------------------------------------------------------
# Cleanup: remove any git metadata, sources, and temp workdir
# ------------------------------------------------------------------------------
find "$BASE" -type d -name .git -prune -exec rm -rf {} + || true
rm -rf "$EPIANOS/_sources" || true
rm -rf "$WORK" || true

# ------------------------------------------------------------------------------
# Index SFZ entrypoints
# ------------------------------------------------------------------------------
find "$BASE" -type f -name '*.sfz' | sort > "$BASE/index.txt"
chmod 0644 "$BASE/index.txt"

EOF
