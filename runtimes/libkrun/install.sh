#!/bin/bash
# Install libkrun via krunvm (Red Hat's OCI-image runner built on libkrun).
# krunvm wraps libkrun and uses buildah to convert OCI images into VM-bootable
# form. Lets us measure raw libkrun cold-start without microsandbox's wrapping,
# which is useful as a diagnostic: any gap between krunvm and msb is msb's CLI
# + agent overhead, not libkrun itself.
set -euo pipefail
if command -v krunvm >/dev/null; then
  echo "krunvm already installed: $(krunvm --version 2>&1 | head -1)"
  exit 0
fi

# On Ubuntu, krunvm isn't in the default apt repos. Build approach varies by
# release; for 24.04 we use the COPR / OBS package if available, else build from
# source. The setup script on the bench box will pick whichever works.
if command -v apt-get >/dev/null && apt-cache show krunvm >/dev/null 2>&1; then
  sudo apt-get install -y krunvm
elif command -v dnf >/dev/null; then
  sudo dnf install -y krunvm
else
  # No prebuilt package. Skip install rather than fail the pipeline; bench.py
  # will report this runtime as failed and continue. To enable, build from
  # source: https://github.com/containers/krunvm (requires libkrun, buildah,
  # asciidoctor, Rust toolchain).
  echo "WARN: no prebuilt krunvm package available; skipping. Build from source"
  echo "      manually if you want libkrun measurements: https://github.com/containers/krunvm"
  exit 0
fi
echo "krunvm installed: $(krunvm --version 2>&1 | head -1)"
