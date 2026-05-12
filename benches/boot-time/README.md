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

Methodology and analysis: [microsandbox.dev/blog/microvm-cold-start-benchmark](https://microsandbox.dev/blog/microvm-cold-start-benchmark).
