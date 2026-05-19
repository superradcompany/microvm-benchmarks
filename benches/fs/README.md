# fs

Guest-visible filesystem benchmarks comparing microsandbox and Docker. Workloads run inside the guest and report their own timings, so results reflect the full I/O stack as seen by the application, not just host-side wall clock.

## Run it

Bare-metal Linux x86_64 with `/dev/kvm`. Tested on Ubuntu 24.04. Requires [`uv`](https://docs.astral.sh/uv/) for the Python harness.

```bash
just setup            # install runtimes (msb, docker)
just bench            # 100 iterations of the mixed suite, writes a dated JSON to results/
just bench-fsmeta     # rootfs-only suite (lookup / readdir / read patterns)
```

Each run produces a new dated file in `results/` (e.g. `results/<timestamp>-bench.json`); nothing is overwritten. Curate by deleting runs you don't want and committing the ones you do. `just clean` removes untracked `results/*.json`, leaving committed runs alone.

`just bench-quick` runs the mixed suite at 3 iterations as a smoke test. For other flags (custom image, workload selection, baseline comparison), see `just bench --help` / `just bench-fsmeta --help`.

## Layout

```
bench_fs.py             # mixed-suite harness
bench_fsmeta.py         # fsmeta-suite harness
_common.py              # shared helpers (run_cmd, try_cleanup, require_bin)
adapters/
  docker.py             # DockerAdapter: pull / start / exec_python / cleanup
  microsandbox.py       # MicrosandboxAdapter: + inspect_image for fsmeta
results/                # dated, hardware-tagged JSONs
```

Per-runtime details (Docker's `--tmpfs /tmp` for fair `/tmp` comparison, msb's `create + exec + stop + remove` sequence, the `msb image inspect` call fsmeta uses to report layer counts) live in the adapter modules. The `boot-time/adapters/` cousins are shell scripts because boot-time invokes runtimes as one-shot CLI calls; fs needs to inject guest Python source per iteration and read JSON back, which is clumsy via shell.

## Results

### 2026-05-19 · macOS arm64 · msb 0.4.6 vs Docker 29.4.0

100 iterations on `python:3.12-slim`. Median per workload, the `docker/msb` ratio (msb wins where >1), and msb's standard deviation.

```text
Workload              Docker (med)  msb (med)  docker/msb      msb σ
────────────────────  ────────────  ─────────  ──────────  ─────────
metadata_scan_stdlib       1.73 ms    1.53 ms       1.13x   ±59.5 µs
read_all_py_stdlib         5.25 ms    4.66 ms       1.13x  ±178.1 µs
deep_tree_traverse         4.37 ms    4.47 ms       0.98x  ±465.1 µs
random_read_stdlib         1.13 ms   992.4 µs       1.14x   ±1.52 ms
small_file_create_1k       5.20 ms    4.71 ms       1.10x   ±1.37 ms
mid_file_create_100        1.20 ms   963.2 µs       1.25x  ±184.8 µs
seq_write_fsync_16m        1.88 ms    1.25 ms       1.50x  ±210.9 µs
shm_write_fsync_16m        1.92 ms    1.24 ms       1.55x  ±336.8 µs
seq_read_16m              702.0 µs   657.1 µs       1.07x   ±42.6 µs
mmap_read_16m             685.9 µs   582.0 µs       1.18x   ±44.7 µs
file_delete_1k            889.3 µs   747.3 µs       1.19x   ±71.4 µs
rename_1k                  1.15 ms   984.0 µs       1.17x   ±80.5 µs
mixed_read_write           4.78 ms    4.44 ms       1.08x  ±240.1 µs
concurrent_read_4t         9.68 ms    4.21 ms       2.30x  ±389.0 µs
```

Raw: [`results/20260519T150922Z-bench.json`](./results/20260519T150922Z-bench.json).

**Reading the numbers:**

- `concurrent_read_4t` is msb's biggest win at 2.3×. Multi-threaded reads of the Python stdlib get the most out of the kernel-EROFS path.
- The fsync rows (`seq_write_fsync_16m`, `shm_write_fsync_16m`) are ~1.5× faster on msb. msb's guest-side tmpfs is a cleaner fsync target than Docker's host-backed tmpfs.
- Everything else clusters in the 1.07–1.25× range. `deep_tree_traverse` at 0.98× is within noise.
- This is a developer-laptop run (macOS arm64). A bare-metal Linux/KVM run (the fs analogue of `boot-time/`'s c3-standard-192-metal table) is still pending.

## Workloads

### `bench_fs.py`: mixed suite

**Rootfs / read-only:**

| Name | What it measures |
|---|---|
| `metadata_scan_stdlib` | `stat()` + `scandir()` over the Python stdlib tree |
| `read_all_py_stdlib` | Sequential read of every `.py` file in stdlib |
| `deep_tree_traverse` | Traverse a 585-dir / 2925-file tree created in `/tmp` |
| `random_read_stdlib` | Read 200 random files from stdlib (non-sequential access) |

**Write path:**

| Name | What it measures |
|---|---|
| `small_file_create_1k` | Create 1000 x 4 KB files in `/tmp` |
| `mid_file_create_100` | Create 100 x 64 KB files in `/tmp` |
| `seq_write_fsync_16m` | Write 16 MB + fsync to `/tmp` |
| `shm_write_fsync_16m` | Write 16 MB + fsync to `/dev/shm` |

**Read-back:**

| Name | What it measures |
|---|---|
| `seq_read_16m` | Sequential read of a 16 MB file from `/tmp` |
| `mmap_read_16m` | `mmap` read of a 16 MB file from `/tmp` |

**Lifecycle:**

| Name | What it measures |
|---|---|
| `file_delete_1k` | Delete 1000 files (re-created before each iteration) |
| `rename_1k` | Rename 1000 files (re-created before each iteration) |

**Mixed / concurrent:**

| Name | What it measures |
|---|---|
| `mixed_read_write` | Alternate reading rootfs files and writing temp files (500 each) |
| `concurrent_read_4t` | Read all stdlib `.py` files across 4 threads |

### `bench_fsmeta.py`: fsmeta-focused suite

| Name | What it measures |
|---|---|
| `metadata_scan_stdlib` | Single-pass `scandir()` + `stat()` over the Python stdlib tree |
| `readdir_rescan_stdlib` | Ten repeated `scandir()` passes across the stdlib directory tree |
| `negative_lookup_stdlib` | Guaranteed-missing `stat()` probes in every stdlib directory |
| `hit_miss_mix_stdlib` | Existing-file `stat()` plus unique missing-path probes per directory |
| `read_all_py_stdlib` | Sequential read of every `.py` file in stdlib |
| `concurrent_negative_lookup_4t` | Parallel negative lookups over the stdlib tree across 4 threads |
| `concurrent_readdir_4t` | Parallel `scandir()` passes over the stdlib tree across 4 threads |

Methodology and analysis: [microsandbox.dev/blog/oci-filesystem-47x-faster](https://microsandbox.dev/blog/oci-filesystem-47x-faster).
