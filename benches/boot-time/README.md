# boot-time

Cold-start wall-clock from CLI invocation to process exit. Same alpine userspace across microsandbox, Docker, and Firecracker.

## Run it

Bare-metal Linux x86_64 with `/dev/kvm`. Tested on Ubuntu 24.04.

```bash
just setup        # install runtimes + build this bench's artifacts
just bench        # 10 iterations + 2 warmups, prints summary, writes a dated JSON to results/
```

Each run produces a new dated file in `results/` (e.g. `results/<timestamp>-bench.json`); nothing is overwritten. Curate by deleting runs you don't want and committing the ones you do.

`just bench-quick` runs the same harness at 3 iterations + 1 warmup as a smoke test. For other flags (skip a runtime, custom iteration count, alternate bench dir), see `python3 bench.py --help`.

Artifact staging (vmlinux, alpine.ext4, fc-config) lands in `~/bench/` by default. Override with `BENCH_DIR=/path bash adapters/firecracker/rootfs.sh` etc., or pass `--bench-dir <path>` to `bench.py`.

## Layout

```
adapters/firecracker/        # Firecracker glue for this bench
  init.sh                    # guest /init: echo READY, reboot
  rootfs.sh                  # builds alpine.ext4 with the above init
  config.sh                  # writes fc-config.json
bench.py                     # the harness
results/                     # dated, hardware-tagged JSONs
```

Docker and msb consume the alpine OCI image directly; no adapter directory needed.

## Results

### 2026-05-12 · c3-standard-192-metal (Intel Sapphire Rapids, bare-metal Linux/KVM)

| runtime | median | mean | min | max | stdev |
|---|---:|---:|---:|---:|---:|
| **libkrun** (krunvm) | **310 ms** | 314 | 289 | 343 | 19 |
| **microsandbox** | **320 ms** | 319 | 293 | 342 | 13 |
| docker | 463 ms | 461 | 416 | 493 | 21 |
| firecracker | 808 ms | 807 | 802 | 811 | 3 |
| smolvm (packed) | 6219 ms | 6347 | 6190 | 7473 | 396 |

Raw: [`results/2026-05-12-c3-standard-192-metal-5way.json`](./results/2026-05-12-c3-standard-192-metal-5way.json).

**Reading the numbers:**

- **libkrun via krunvm** clocks ~10 ms faster than microsandbox. That's the cost of msb's CLI + agent wrapper around the same libkrun underneath. Useful diagnostic; the overhead is small.
- **microsandbox vs Firecracker**: 2.5× faster (320 vs 808 ms). Holds across runs.
- **Docker faster than Firecracker** because Docker doesn't boot a kernel (host kernel + namespaces only).
- **smolvm at 6.2 s** is dominated by smolvm's daemon-spawn architecture. The packed-binary mode pre-bakes the OCI image (no network in the measured path), but each ephemeral invocation still spins up a per-VM daemon process, waits for vsock handshake, runs the workload, and tears down. The actual VM boot inside is fast (likely sub-second). The 6 s is a smolvm architectural choice, not a hypervisor cost.

### Pending runtimes

| runtime | status | notes |
|---|---|---|
| cloud-hypervisor | adapter wrapper works in isolation but kernel panics on init reach in the bench loop | Wrapper at `adapters/cloud-hypervisor/run.sh` SIGPIPEs CH when the guest /init prints READY. Boots cleanly when invoked alone, but inside the bench loop the kernel panics before reaching userspace, likely a disk-device naming or virtio-blk config difference vs Firecracker. Needs deeper CH investigation. |

Methodology and analysis: [microsandbox.dev/blog/microvm-cold-start-benchmark](https://microsandbox.dev/blog/microvm-cold-start-benchmark).
