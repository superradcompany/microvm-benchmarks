#!/bin/bash
# Install libkrun via krunvm (Red Hat's OCI-image runner built on libkrun).
# krunvm wraps libkrun and uses buildah to convert OCI images into VM-bootable
# form. Lets us measure raw libkrun cold-start without microsandbox's wrapping,
# which is useful as a diagnostic: any gap between krunvm and msb is msb's CLI
# + agent overhead, not libkrun itself.
set -euo pipefail
if command -v krunvm >/dev/null; then
  echo "krunvm already installed: $(krunvm --version 2>&1 | head -1)"
  exit 0
fi

# On Ubuntu, krunvm isn't in the default apt repos. Build approach varies by
# release; for 24.04 we use the COPR / OBS package if available, else build from
# source. The setup script on the bench box will pick whichever works.
if command -v apt-get >/dev/null && apt-cache show krunvm >/dev/null 2>&1; then
  sudo apt-get install -y krunvm
  echo "krunvm installed: $(krunvm --version 2>&1 | head -1)"
  exit 0
fi
if command -v dnf >/dev/null; then
  sudo dnf install -y krunvm
  echo "krunvm installed: $(krunvm --version 2>&1 | head -1)"
  exit 0
fi

# No prebuilt package. Build libkrun + libkrunfw + krunvm from source.
# Ubuntu 24.04 ships rustc 1.75 which is too old (libkrun needs edition2024),
# so we install rustup-managed stable Rust alongside.
echo "no prebuilt krunvm; building from source"
sudo apt-get install -y -q build-essential libclang-dev llvm-dev clang \
  flex bison libelf-dev bc cpio xz-utils libssh2-1-dev libdbus-1-dev libudev-dev \
  buildah asciidoctor patch pkg-config libcap-dev python3-pyelftools >/dev/null

if ! command -v rustup >/dev/null && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal >/dev/null
fi
# shellcheck disable=SC1091
source "$HOME/.cargo/env"

cd /tmp
[ -d libkrun ] || git clone --depth 1 https://github.com/containers/libkrun.git
( cd libkrun && make && sudo make install )

[ -d libkrunfw ] || git clone --depth 1 https://github.com/containers/libkrunfw.git
( cd libkrunfw && make && sudo make install )

[ -d krunvm ] || git clone --depth 1 https://github.com/containers/krunvm.git
( cd krunvm && RUSTFLAGS="-L /usr/local/lib64" make && sudo install -m 755 target/release/krunvm /usr/local/bin/krunvm )

echo "/usr/local/lib64" | sudo tee /etc/ld.so.conf.d/libkrun.conf >/dev/null
sudo ldconfig
echo "krunvm installed: $(krunvm --version 2>&1 | head -1)"
