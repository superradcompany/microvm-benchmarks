#!/bin/bash
# Write fc-config.json for this pillar: 1 vCPU, 128 MiB RAM, paths resolved
# against BENCH_DIR. Other pillars (snapshot, memory) supply their own config.sh
# with different shapes.
set -euo pipefail
DEST_DIR="${BENCH_DIR:-$HOME/bench}"
mkdir -p "$DEST_DIR"
cat > "$DEST_DIR/fc-config.json" <<EOF
{
  "boot-source": {
    "kernel_image_path": "$DEST_DIR/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=-1 pci=off init=/init"
  },
  "drives": [{
    "drive_id": "rootfs",
    "path_on_host": "$DEST_DIR/alpine.ext4",
    "is_root_device": true,
    "is_read_only": false
  }],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 128
  }
}
EOF
echo "fc-config.json written to $DEST_DIR/fc-config.json"
