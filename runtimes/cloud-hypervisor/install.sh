#!/bin/bash
# Install Cloud Hypervisor from the official GitHub release. Idempotent.
# Cloud Hypervisor boots Firecracker-compatible vmlinux kernels, so we reuse the
# kernel that runtimes/firecracker/kernel.sh downloads.
set -euo pipefail
CH_VERSION="${CH_VERSION:-v48.0}"
ARCH="$(uname -m)"
if command -v cloud-hypervisor >/dev/null; then
  echo "cloud-hypervisor already installed: $(cloud-hypervisor --version | head -1)"
  exit 0
fi
cd /tmp
curl -fsSL -o cloud-hypervisor-static \
  "https://github.com/cloud-hypervisor/cloud-hypervisor/releases/download/${CH_VERSION}/cloud-hypervisor-static"
sudo install -m 755 cloud-hypervisor-static /usr/local/bin/cloud-hypervisor
echo "cloud-hypervisor installed: $(cloud-hypervisor --version | head -1)"
