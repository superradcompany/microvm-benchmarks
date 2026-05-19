#!/usr/bin/env python3
"""Cold-start boot-time benchmark: microVM and container runtimes.

Wall-clock from CLI invocation to process exit. Same alpine userspace across
all runtimes. Run after `just setup` has prepared the bench directory with
vmlinux + alpine.ext4 + fc-config.json and the krunvm template.
"""

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def runtime_paths() -> dict[str, str]:
    home = os.path.expanduser("~")
    return {
        "msb": f"{home}/.microsandbox/bin/msb",
        "docker": shutil.which("docker") or "docker",
        "firecracker": shutil.which("firecracker") or "firecracker",
        "cloud-hypervisor": shutil.which("cloud-hypervisor") or "cloud-hypervisor",
        "smolvm": shutil.which("smolvm") or "smolvm",
        "krunvm": shutil.which("krunvm") or "krunvm",
    }


def run_once(cmd: list[str], cwd: str | None = None) -> float:
    t0 = time.perf_counter()
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    elapsed = time.perf_counter() - t0
    if proc.returncode != 0:
        raise RuntimeError(
            f"cmd failed ({proc.returncode}): {' '.join(cmd)}\n"
            f"stdout: {proc.stdout[-500:]!r}\nstderr: {proc.stderr[-500:]!r}"
        )
    return elapsed


def bench(
    label: str,
    cmd: list[str],
    iterations: int,
    warmup: int,
    cwd: str | None = None,
) -> dict:
    print(f"\n[{label}] warmup x{warmup}", flush=True)
    for i in range(warmup):
        t = run_once(cmd, cwd=cwd)
        print(f"  warmup {i+1}: {t*1000:.1f} ms", flush=True)

    print(f"[{label}] timed x{iterations}", flush=True)
    samples = []
    for i in range(iterations):
        t = run_once(cmd, cwd=cwd)
        samples.append(t)
        print(f"  run {i+1}: {t*1000:.1f} ms", flush=True)

    samples_ms = [s * 1000 for s in samples]
    p90 = (
        statistics.quantiles(samples_ms, n=10)[-1]
        if len(samples_ms) >= 10
        else max(samples_ms)
    )
    p99 = (
        statistics.quantiles(samples_ms, n=100)[-1]
        if len(samples_ms) >= 100
        else max(samples_ms)
    )
    return {
        "label": label,
        "cmd": cmd,
        "iterations": iterations,
        "samples_ms": samples_ms,
        "median_ms": statistics.median(samples_ms),
        "mean_ms": statistics.mean(samples_ms),
        "stdev_ms": statistics.stdev(samples_ms) if len(samples_ms) > 1 else 0.0,
        "min_ms": min(samples_ms),
        "max_ms": max(samples_ms),
        "p90_ms": p90,
        "p99_ms": p99,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--iterations", type=int, default=10)
    ap.add_argument("--warmup", type=int, default=2)
    ap.add_argument(
        "--bench-dir",
        type=Path,
        default=Path.home() / "bench",
        help="Where setup placed vmlinux/alpine.ext4/fc-config.json (default ~/bench). Artifact staging only; results land in results/.",
    )
    ap.add_argument("--run-name", default="bench")
    ap.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Override the default benches/boot-time/results/<timestamp>-<runname>.json path",
    )
    ap.add_argument(
        "--skip",
        action="append",
        default=[],
        choices=[
            "microsandbox", "docker", "firecracker",
            "cloud-hypervisor", "smolvm", "libkrun",
        ],
    )
    args = ap.parse_args()

    if args.output:
        output = args.output
    else:
        results_dir = Path(__file__).resolve().parent / "results"
        results_dir.mkdir(parents=True, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        safe = "".join(c if c.isalnum() or c in "-_" else "-" for c in args.run_name)
        output = results_dir / f"{ts}-{safe}.json"

    bins = runtime_paths()
    fc_config = args.bench_dir / "fc-config.json"
    vmlinux = args.bench_dir / "vmlinux"
    rootfs = args.bench_dir / "alpine.ext4"
    ch_cmdline = (
        "console=ttyS0 root=/dev/vda rw init=/init reboot=k panic=-1 pci=off"
    )
    krunvm_name = os.environ.get("KRUNVM_NAME", "bench-alpine")

    runs = [
        ("microsandbox", [bins["msb"], "run", "alpine", "--", "/bin/true"], None),
        ("docker", [bins["docker"], "run", "--rm", "alpine:latest", "/bin/true"], None),
        ("firecracker", [bins["firecracker"], "--no-api", "--config-file", str(fc_config)], str(args.bench_dir)),
        (
            "cloud-hypervisor",
            ["bash", str(Path(__file__).parent / "adapters" / "cloud-hypervisor" / "run.sh")],
            str(args.bench_dir),
        ),
        ("smolvm", [str(args.bench_dir / "alpine-packed"), "run", "--", "/bin/true"], None),
        ("libkrun", ["buildah", "unshare", bins["krunvm"], "start", krunvm_name, "/bin/true"], None),
    ]

    print(f"iterations: {args.iterations} (warmup {args.warmup})")
    print(f"bench-dir:  {args.bench_dir}")
    for label, cmd, _cwd in runs:
        print(f"  {label}: {' '.join(cmd)}")

    results = []
    for label, cmd, cwd in runs:
        if label in args.skip:
            print(f"[{label}] SKIP", flush=True)
            continue
        try:
            results.append(bench(label, cmd, args.iterations, args.warmup, cwd=cwd))
        except Exception as e:
            print(f"[{label}] FAILED: {e}", file=sys.stderr, flush=True)
            results.append({"label": label, "error": str(e)})

    print("\n=== summary ===")
    print(
        f"{'runtime':<14} {'median':>10} {'mean':>10} {'min':>10} {'max':>10} {'p90':>10} {'stdev':>10}"
    )
    for r in results:
        if "error" in r:
            print(f"{r['label']:<14} ERROR: {r['error'][:80]}")
            continue
        print(
            f"{r['label']:<14} "
            f"{r['median_ms']:>8.1f}ms "
            f"{r['mean_ms']:>8.1f}ms "
            f"{r['min_ms']:>8.1f}ms "
            f"{r['max_ms']:>8.1f}ms "
            f"{r['p90_ms']:>8.1f}ms "
            f"{r['stdev_ms']:>8.1f}ms"
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(results, indent=2))
    print(f"\nresults: {output}")


if __name__ == "__main__":
    main()
