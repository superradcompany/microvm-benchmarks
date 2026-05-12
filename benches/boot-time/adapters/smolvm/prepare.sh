#!/bin/bash
# Build a .smolmachine packed artifact from alpine. smolvm's ephemeral
# `machine run --image` always pulls from the registry (no apples-to-apples
# cached-image cold-start path), so we use pack mode instead: the OCI image
# is baked into a self-contained binary at prepare time, then per-iteration
# `<binary> run -- /bin/true` boots a fresh ephemeral VM from the local
# artifact. No network round-trip in the measured path.
set -euo pipefail
DEST_DIR="${BENCH_DIR:-$HOME/bench}"
mkdir -p "$DEST_DIR"
if ! command -v smolvm >/dev/null; then
  echo "WARN: smolvm not installed; skipping adapter prepare."
  exit 0
fi
if [ -x "$DEST_DIR/alpine-packed" ] && [ -f "$DEST_DIR/alpine-packed.smolmachine" ]; then
  echo "smolvm packed artifact already exists at $DEST_DIR/alpine-packed"
  exit 0
fi
smolvm pack create --image alpine --output "$DEST_DIR/alpine-packed"
echo "smolvm packed artifact at $DEST_DIR/alpine-packed"
