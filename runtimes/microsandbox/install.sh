#!/bin/bash
# Install microsandbox via the official installer. Idempotent.
set -euo pipefail
MSB="$HOME/.microsandbox/bin/msb"
if [ -x "$MSB" ]; then
  echo "msb already installed: $($MSB --version | head -1)"
  exit 0
fi
curl -sSL https://install.microsandbox.dev | sh >/dev/null
echo "msb installed: $($MSB --version | head -1)"
