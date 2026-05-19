"""Shared helpers for the fs benchmarks (bench_fs, bench_fsmeta) and the
per-runtime adapter modules.

Kept as a leaf module with no project-internal imports so adapters can
import it without circular references.
"""

from __future__ import annotations

import shutil
import subprocess
import sys


def run_cmd(
    cmd: list[str],
    timeout: int,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
    """Run a command, capturing stdout/stderr. Raises on `check=True` non-zero."""
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if check and proc.returncode != 0:
        msg = proc.stderr.strip() or proc.stdout.strip() or f"failed: {' '.join(cmd)}"
        raise RuntimeError(msg)
    return proc


def try_cleanup(cmd: list[str], timeout: int = 30) -> None:
    """Best-effort cleanup. Swallows all errors; used in `finally` blocks."""
    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except Exception:
        pass


def require_bin(path: str, label: str) -> str:
    """Resolve a binary path against PATH. Exits the process if unfound."""
    resolved = shutil.which(path)
    if not resolved:
        sys.exit(f"{label} not found: {path}")
    return resolved
