#!/bin/bash -e

on_chroot <<'EOF'
set -euo pipefail

cd /usr/src

rm -rf sfizz-ui

# IMPORTANT: pull submodules (contains the CMake helpers like BuildType/OptionEx)
git clone --recurse-submodules --shallow-submodules https://github.com/sfztools/sfizz-ui.git
cd sfizz-ui

# If you prefer depth=1, keep it, but still recurse submodules:
# git clone --depth=1 --recurse-submodules --shallow-submodules https://github.com/sfztools/sfizz-ui.git

rm -rf build

cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DSFIZZ_JACK=OFF \
  -DSFIZZ_SHARED=OFF \
  -DSFIZZ_RENDER=OFF \
  -DPLUGIN_LV2=ON \
  -DPLUGIN_LV2_UI=OFF \
  -DPLUGIN_VST3=OFF

cmake --build build -j"$(nproc)"
cmake --install build
ldconfig

EOF
