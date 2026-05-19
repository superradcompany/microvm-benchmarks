"""Microsandbox adapter for fs benchmarks.

msb's lifecycle is split across multiple verbs: `pull`, `create -n`, `exec`,
`stop`, `remove`. The adapter sequences them so the bench only needs
`start` / `exec_python` / `cleanup`.

`inspect_image` is msb-specific and only used by bench_fsmeta.
"""

from __future__ import annotations

import json
import subprocess
import time
from typing import Any

from _common import run_cmd, try_cleanup  # type: ignore[import-not-found]


class MicrosandboxAdapter:
    label = "microsandbox"

    def __init__(self, bin_path: str):
        self.bin = bin_path

    # ----- one-time per run -----

    def version(self) -> str:
        return run_cmd([self.bin, "--version"], timeout=30, check=True).stdout.strip()

    def pull_image(self, image: str, timeout: int) -> float:
        t0 = time.perf_counter()
        run_cmd([self.bin, "pull", image, "--quiet"], timeout=timeout, check=True)
        return time.perf_counter() - t0

    def inspect_image(self, image: str, timeout: int) -> dict[str, Any]:
        """Return `{digest, layer_count, size_bytes}` or `{error: ...}`."""
        proc = run_cmd(
            [self.bin, "image", "inspect", image, "--format", "json"],
            timeout=timeout,
        )
        if proc.returncode != 0:
            return {"error": proc.stderr.strip() or proc.stdout.strip()}
        payload = json.loads(proc.stdout)
        return {
            "digest": payload.get("digest"),
            "layer_count": payload.get("layer_count"),
            "size_bytes": payload.get("size_bytes"),
        }

    # ----- per workload -----

    def start(self, image: str, name: str, timeout: int) -> None:
        run_cmd(
            [self.bin, "create", "-n", name, image, "--quiet"],
            timeout=timeout,
            check=True,
        )

    def exec_python(
        self,
        name: str,
        code: str,
        iterations: int,
        timeout: int,
    ) -> subprocess.CompletedProcess[str]:
        return run_cmd(
            [self.bin, "exec", name, "--", "python", "-c", code, str(iterations)],
            timeout=timeout,
        )

    def cleanup(self, name: str) -> None:
        try_cleanup([self.bin, "stop", name])
        try_cleanup([self.bin, "remove", name])
