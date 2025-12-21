#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

cd /usr/src

# Fresh clone each build (includes needed CMake helpers via submodules)
rm -rf sfizz-ui
git clone --recurse-submodules --shallow-submodules https://github.com/sfztools/sfizz-ui.git
cd sfizz-ui

rm -rf build
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSFIZZ_JACK=ON \
  -DSFIZZ_SHARED=ON \
  -DSFIZZ_RENDER=OFF \
  -DPLUGIN_LV2=ON \
  -DPLUGIN_LV2_UI=OFF \
  -DPLUGIN_VST3=OFF

cmake --build build -j"$(nproc)"
cmake --install build
ldconfig || true

# quick sanity (non-fatal)
command -v sfizz_jack >/dev/null || true

# cleanup build tree (prevents /usr/src leftovers)
cd / && rm -rf /usr/src/sfizz-ui
EOF
