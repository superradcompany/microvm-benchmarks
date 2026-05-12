#!/bin/bash
# Install Firecracker + jailer from the official GitHub release. Idempotent.
set -euo pipefail
FC_VERSION="${FC_VERSION:-v1.13.1}"
ARCH="$(uname -m)"
if command -v firecracker >/dev/null; then
  echo "firecracker already installed: $(firecracker --version | head -1)"
  exit 0
fi
cd /tmp
curl -sL -o firecracker.tgz \
  "https://github.com/firecracker-microvm/firecracker/releases/download/${FC_VERSION}/firecracker-${FC_VERSION}-${ARCH}.tgz"
tar -xzf firecracker.tgz
sudo install -m 755 "release-${FC_VERSION}-${ARCH}/firecracker-${FC_VERSION}-${ARCH}" /usr/local/bin/firecracker
sudo install -m 755 "release-${FC_VERSION}-${ARCH}/jailer-${FC_VERSION}-${ARCH}" /usr/local/bin/jailer
echo "firecracker installed: $(firecracker --version | head -1)"
