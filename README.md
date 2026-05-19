# sandbox-bench

Reproducible cross-runtime benchmarks for microVMs and containers. Same image, same workload, same hardware, methodology written down.

## Layout

```
runtimes/<name>/                       # how to install a runtime (shared across benches)
benches/<bench>/                       # one benchmark dimension (e.g. boot-time)
benches/<bench>/adapters/<runtime>/    # how this bench uses a runtime
benches/<bench>/results/               # dated, machine-tagged result JSONs
```

## Benches

- [`benches/boot-time/`](./benches/boot-time): cold-start wall-clock (microsandbox, Docker, Firecracker)
- [`benches/fs/`](./benches/fs): guest-visible filesystem performance (microsandbox vs Docker)

## Running

Requires [`just`](https://github.com/casey/just). Bare-metal Linux x86_64 with `/dev/kvm`.

```bash
just install                  # install all runtimes
just setup boot-time          # build this bench's artifacts
just bench boot-time          # run the benchmark
```

Don't have `just`? Each recipe is a shell command; read the relevant `justfile` and copy the lines you need.

## Contributing

- **A new runtime:** add `runtimes/<your-runtime>/install.sh`. For each bench you want it measured in, add adapter glue under `benches/<bench>/adapters/<your-runtime>/` (or `<your-runtime>.py`, depending on the bench; see below).
- **A new bench:** add `benches/<bench>/` with its own `justfile` and harness (`bench.py` or similar), plus `adapters/` and `results/`. Mirror `benches/boot-time/` (shell adapters) or `benches/fs/` (Python adapters), whichever matches your bench's needs.
- **A fix or alternative configuration** for an existing runtime in an existing bench: PR to the relevant `benches/<bench>/adapters/<runtime>/` directory.

### Adapter format

Adapters are intentionally not standardized on a single language. The right format depends on how the bench calls them:

- **`runtimes/<name>/install.sh`** is always shell. It's `apt-get install` / `curl | bash`.
- **`benches/<bench>/adapters/<runtime>/*.sh`** for one-shot setup steps invoked from the bench's `justfile` (filesystem assembly, config emission, template create). Shell composes naturally with `dd`/`mkfs`/`sudo mount` and the privilege escalation these need. `benches/boot-time/` uses this exclusively.
- **`benches/<bench>/adapters/<runtime>.py`** (matching the harness language) for in-loop orchestration with structured I/O: when the harness calls into the adapter per workload or per iteration, passes multi-line code, and parses results back. `benches/fs/` uses this because it injects guest Python source and reads JSON timings; shell adapters there would mean stuffing source through argv and parsing stdout for elapsed times.

A bench can have one flavor, the other, or both (a shell `prepare.sh` for setup plus a Python adapter for in-loop work).

PRs that improve methodology or make a runtime look fairer are welcome.

## License

TBD.
