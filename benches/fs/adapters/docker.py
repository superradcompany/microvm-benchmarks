"""Docker adapter for fs benchmarks.

The `--tmpfs /tmp` mount is configurable per bench: bench_fs.py passes
`tmpfs_mounts=("/tmp",)` so `/tmp` workloads on Docker match the OCI msb
runtime (which mounts `/tmp` as guest tmpfs by default). bench_fsmeta
leaves it unset because it doesn't exercise `/tmp`.
"""

from __future__ import annotations

import subprocess
import time
from collections.abc import Sequence

from _common import run_cmd, try_cleanup  # type: ignore[import-not-found]


class DockerAdapter:
    label = "docker"

    def __init__(self, bin_path: str, tmpfs_mounts: Sequence[str] = ()):
        self.bin = bin_path
        self.tmpfs_mounts = tuple(tmpfs_mounts)

    # ----- one-time per run -----

    def version(self) -> str:
        return run_cmd(
            [self.bin, "info", "--format", "{{.ServerVersion}}"],
            timeout=30,
            check=True,
        ).stdout.strip()

    def pull_image(self, image: str, timeout: int) -> float:
        t0 = time.perf_counter()
        run_cmd([self.bin, "pull", image], timeout=timeout, check=True)
        return time.perf_counter() - t0

    # ----- per workload -----

    def start(self, image: str, name: str, timeout: int) -> None:
        """Start a detached container named `name` running `sleep infinity`."""
        cmd = [self.bin, "run", "-d", "--name", name]
        for mount in self.tmpfs_mounts:
            cmd.extend(["--tmpfs", mount])
        cmd.extend([image, "sleep", "infinity"])
        run_cmd(cmd, timeout=timeout, check=True)

    def exec_python(
        self,
        name: str,
        code: str,
        iterations: int,
        timeout: int,
    ) -> subprocess.CompletedProcess[str]:
        return run_cmd(
            [self.bin, "exec", name, "python", "-c", code, str(iterations)],
            timeout=timeout,
        )

    def cleanup(self, name: str) -> None:
        try_cleanup([self.bin, "rm", "-f", name])
