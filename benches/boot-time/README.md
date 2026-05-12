# boot-time

Cold-start wall-clock from CLI invocation to process exit. Same alpine userspace across microsandbox, Docker, and Firecracker.

## Run it

Bare-metal Linux x86_64 with `/dev/kvm`. Tested on Ubuntu 24.04.

```bash
just setup        # install runtimes + build this bench's artifacts
just bench        # 10 iterations + 2 warmups, prints summary, writes results.json
```

Artifacts land in `~/bench/` by default. Override with `BENCH_DIR=/path bash adapters/firecracker/rootfs.sh` etc.

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

### 2026-05-11 · c3-standard-192-metal (Intel Sapphire Rapids, bare-metal Linux/KVM)

| runtime | median | mean | min | max | stdev |
|---|---:|---:|---:|---:|---:|
| **microsandbox** | **326 ms** | 323 | 312 | 331 | 7 |
| docker | 458 ms | 457 | 438 | 484 | 14 |
| firecracker | 806 ms | 805 | 795 | 815 | 7 |

Raw: [`results/2026-05-11-c3-standard-192-metal.json`](./results/2026-05-11-c3-standard-192-metal.json).

### 2026-05-12 · c3-standard-192-metal (rerun, same hardware spec)

Reproducibility check on a fresh c3-standard-192-metal instance.

| runtime | median | mean | min | max | stdev |
|---|---:|---:|---:|---:|---:|
| **microsandbox** | **330 ms** | 322 | 293 | 336 | 16 |
| docker | 462 ms | 465 | 429 | 498 | 20 |
| firecracker | 806 ms | 806 | 796 | 812 | 5 |

Raw: [`results/2026-05-12-c3-standard-192-metal-rerun.json`](./results/2026-05-12-c3-standard-192-metal-rerun.json). Same ratios as the prior run, within stdev. Reproducible.

### Pending runtimes

| runtime | status | notes |
|---|---|---|
| cloud-hypervisor | works in isolation, hangs in bench | Guest reboot doesn't trigger CH exit the way Firecracker handles it. Needs investigation of CH's shutdown signaling (different reboot kernel arg, or API-driven shutdown). Adapter stub at `adapters/cloud-hypervisor/` to add. |
| smolvm | needs persistent-mode adapter | Ephemeral `machine run` always re-pulls (~7.5 s pull dominates a 300 ms boot). Persistent-mode (`machine create` + `start`) needs a different harness pattern. |
| libkrun (via krunvm) | not installed | krunvm isn't packaged for Ubuntu 24.04. Needs source build of libkrun + krunvm. Would measure raw libkrun overhead vs microsandbox. |

Methodology and analysis: [microsandbox.dev/blog/microvm-cold-start-benchmark](https://microsandbox.dev/blog/microvm-cold-start-benchmark).
