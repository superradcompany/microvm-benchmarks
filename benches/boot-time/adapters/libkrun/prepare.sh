#!/bin/bash
# Pre-create the krunvm VM template from the alpine OCI image. One-time setup;
# subsequent `krunvm start bench-alpine /bin/true` invocations boot a fresh
# microVM from the template. This mirrors the "image pre-pulled, fresh sandbox
# per iteration" pattern used for the other runtimes.
set -euo pipefail
if ! command -v krunvm >/dev/null; then
  echo "WARN: krunvm not installed; skipping libkrun adapter prepare. Bench will report libkrun as failed."
  exit 0
fi
VM_NAME="${KRUNVM_NAME:-bench-alpine}"
if krunvm list 2>/dev/null | grep -q "^${VM_NAME}\b"; then
  echo "krunvm template '${VM_NAME}' already exists"
  exit 0
fi
krunvm create docker.io/library/alpine --name "$VM_NAME"
echo "krunvm template '${VM_NAME}' created"
