on_chroot <<'EOF'
set -e

cd /usr/src

if [ -d sfizz ]; then
  echo "sfizz source already exists, updating"
  cd sfizz
  git fetch --depth=1 origin
  git reset --hard origin/HEAD
else
  git clone --depth=1 https://github.com/sfztools/sfizz.git
  cd sfizz
fi

cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DSFIZZ_JACK=ON \
  -DSFIZZ_SHARED=ON

cmake --build build -j$(nproc)
cmake --install build
ldconfig
EOF
