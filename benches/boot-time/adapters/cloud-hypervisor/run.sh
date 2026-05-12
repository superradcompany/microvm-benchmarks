#!/bin/bash
# Cloud Hypervisor boot-time wrapper. CH doesn't exit on guest reboot the way
# Firecracker does; it reboots the guest by default. We pipe CH's serial output
# through `grep -q READY` which exits as soon as the guest's /init prints
# "READY", closing the pipe and SIGPIPE-ing CH so it terminates.
#
# The measurement boundary is "spawn → guest userspace READY", which is
# ~10 ms tighter than Firecracker's "spawn → process exit on guest reboot".
# That's within measurement noise but worth knowing.
set -uo pipefail
BENCH_DIR="${BENCH_DIR:-$HOME/bench}"
cloud-hypervisor \
  --kernel "$BENCH_DIR/vmlinux" \
  --disk path="$BENCH_DIR/alpine.ext4",readonly=on \
  --cmdline "console=ttyS0 root=/dev/vda rw init=/init reboot=t panic=-1 pci=off" \
  --cpus boot=1 \
  --memory size=128M \
  --serial tty \
  --console off 2>&1 | grep -q READY
