#!/bin/sh
# Firecracker guest init. Signals readiness then reboots, which Firecracker
# treats as the VM exit signal.
echo READY
exec /bin/busybox reboot -f
