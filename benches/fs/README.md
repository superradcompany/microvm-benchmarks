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

### 2026-05-08 · v0.3.14 → v0.4 mixed FS suite

Across 14 mixed guest-visible filesystem workloads, the geometric mean speedup from v0.3.14 to v0.4 was **47.18×**. Eight biggest movers (`python:3.12-slim`, 3 iterations, `bench_fs.py --baseline` mode):

| workload | speedup | exercises |
|---|---:|---|
| `file_delete_1k` | 1109.94× | /tmp tmpfs |
| `rename_1k` | 876.58× | /tmp tmpfs |
| `small_file_create_1k` | 240.78× | /tmp tmpfs |
| `metadata_scan_stdlib` | 240.28× | rootfs |
| `read_all_py_stdlib` | 116.40× | rootfs |
| `deep_tree_traverse` | 47.16× | /tmp tmpfs |
| `concurrent_read_4t` | 20.93× | rootfs |
| `random_read_stdlib` | 4.01× | rootfs |

**Reading the numbers:**

- The rootfs rows (`metadata_scan_stdlib`, `read_all_py_stdlib`, `concurrent_read_4t`, `random_read_stdlib`) are the cleanest measure of the new OCI path: lookups and reads now stay inside the guest kernel instead of bouncing through the host.
- The /tmp tmpfs rows (`file_delete_1k`, `rename_1k`, `small_file_create_1k`, `deep_tree_traverse`) come from cutting the FUSE round-trip on guest tmpfs workloads, which is a separate runtime decision rather than the EROFS lower-rootfs path.

### Pending: cross-runtime (msb vs docker) absolute-time run

A canonical bare-metal Linux/KVM run comparing the two runtimes head-to-head per workload (the analogue of `boot-time/`'s 5-way table) hasn't been committed yet. When it lands it will appear here in the same shape.

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

Methodology and analysis: [microsandbox.dev/blog/block-backed-rootfs](https://microsandbox.dev/blog/block-backed-rootfs).
