#!/bin/bash
# Install smolvm from smol-machines/smolvm releases. Idempotent.
# smolvm is libkrun-based and consumes OCI images directly via its own CLI, so
# no per-bench adapter is needed beyond invoking the binary.
set -euo pipefail
SMOLVM_VERSION="${SMOLVM_VERSION:-latest}"
ARCH="$(uname -m)"
if command -v smolvm >/dev/null; then
  echo "smolvm already installed: $(smolvm --version 2>&1 | head -1)"
  exit 0
fi

# Resolve the release tag if 'latest'.
if [ "$SMOLVM_VERSION" = "latest" ]; then
  SMOLVM_VERSION="$(curl -fsSL https://api.github.com/repos/smol-machines/smolvm/releases/latest | grep -oE '"tag_name": *"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
# Asset name strips the leading 'v' from the tag: smolvm-0.6.2-linux-x86_64.tar.gz.
SMOLVM_NUM="${SMOLVM_VERSION#v}"
URL="https://github.com/smol-machines/smolvm/releases/download/${SMOLVM_VERSION}/smolvm-${SMOLVM_NUM}-linux-${ARCH}.tar.gz"
if ! curl -fsSL -o smolvm.tgz "$URL"; then
  echo "ERROR: failed to download smolvm from $URL"
  echo "Check https://github.com/smol-machines/smolvm/releases and adjust SMOLVM_VERSION."
  exit 1
fi
tar -xzf smolvm.tgz
# Distribution is a directory with the wrapper script + smolvm-bin + agent-rootfs/ +
# storage-template.ext4. The wrapper expects all of those as siblings, so install
# the whole tree into /opt/smolvm and symlink the wrapper onto $PATH.
EXTRACTED="$(find "$WORK" -maxdepth 2 -type f -name smolvm-bin -printf '%h\n' | head -1)"
if [ -z "$EXTRACTED" ]; then
  echo "ERROR: smolvm distribution layout unexpected"
  ls -R "$WORK"
  exit 1
fi
sudo rm -rf /opt/smolvm
sudo mkdir -p /opt/smolvm
sudo cp -a "$EXTRACTED"/. /opt/smolvm/
sudo ln -sf /opt/smolvm/smolvm /usr/local/bin/smolvm
echo "smolvm installed: $(smolvm --version 2>&1 | head -1)"
