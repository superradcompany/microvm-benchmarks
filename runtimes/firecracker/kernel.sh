#!/bin/bash
# Download Firecracker's reference CI kernel into BENCH_DIR. Shared across
# pillars: the same vmlinux works whether you're measuring boot time, snapshots,
# or anything else. Pillars consume the downloaded vmlinux at $BENCH_DIR/vmlinux.
set -euo pipefail
DEST_DIR="${BENCH_DIR:-$HOME/bench}"
KERNEL_URL="${FC_KERNEL_URL:-https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.13/x86_64/vmlinux-6.1.141}"
mkdir -p "$DEST_DIR"
if [ -f "$DEST_DIR/vmlinux" ]; then
  echo "kernel already present at $DEST_DIR/vmlinux"
  exit 0
fi
curl -sL -o "$DEST_DIR/vmlinux" "$KERNEL_URL"
echo "kernel downloaded to $DEST_DIR/vmlinux"
