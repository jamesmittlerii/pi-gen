#!/bin/bash -e

on_chroot <<'EOF'
set -e

cd /usr/src
git clone --depth=1 https://github.com/sfztools/sfizz.git
cd sfizz

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DSFIZZ_JACK=ON \
  -DSFIZZ_SHARED=ON

cmake --build build -j$(nproc)
cmake --install build
ldconfig
EOF

