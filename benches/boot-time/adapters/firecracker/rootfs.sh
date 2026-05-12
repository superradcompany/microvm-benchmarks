#!/bin/bash
# Build an ext4 rootfs from the alpine OCI image, with this pillar's init.sh
# embedded at /init. Pillar-specific because init defines what "boot complete"
# means for boot-time (echo READY, then reboot). Other pillars supply their own
# rootfs.sh with a different init.
set -euo pipefail
DEST_DIR="${BENCH_DIR:-$HOME/bench}"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DEST_DIR"
cd "$DEST_DIR"
sudo apt-get install -y -q e2fsprogs >/dev/null 2>&1 || true
sudo docker pull alpine:latest >/dev/null
CID="$(sudo docker create alpine:latest)"
sudo docker export "$CID" -o alpine-rootfs.tar
sudo docker rm "$CID" >/dev/null
dd if=/dev/zero of=alpine.ext4 bs=1M count=128 status=none
mkfs.ext4 -F -q alpine.ext4
mkdir -p rootfs-mnt
sudo mount -o loop alpine.ext4 rootfs-mnt
sudo tar -xf alpine-rootfs.tar -C rootfs-mnt
sudo cp "$HERE/init.sh" rootfs-mnt/init
sudo chmod +x rootfs-mnt/init
sudo umount rootfs-mnt
rm -rf rootfs-mnt
echo "rootfs built at $DEST_DIR/alpine.ext4"
