#!/bin/bash
# Install Docker via the official convenience script. Idempotent.
set -euo pipefail
if command -v docker >/dev/null; then
  echo "docker already installed: $(docker --version)"
  exit 0
fi
curl -fsSL https://get.docker.com | sudo sh >/dev/null
sudo usermod -aG docker "$USER"
echo "docker installed: $(docker --version 2>/dev/null || sudo docker --version)"
echo "note: log out/in for docker group membership to apply"
