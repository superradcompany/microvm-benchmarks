# microvm-benchmarks

Reproducible cross-runtime benchmarks for microVMs and containers. Same image, same workload, same hardware, methodology written down.

## Layout

```
runtimes/<name>/                       # how to install a runtime (shared across benches)
benches/<bench>/                       # one benchmark dimension (e.g. boot-time)
benches/<bench>/adapters/<runtime>/    # how this bench uses a runtime
benches/<bench>/results/               # dated, machine-tagged result JSONs
```

## Benches

- [`benches/boot-time/`](./benches/boot-time) — cold-start wall-clock (microsandbox, Docker, Firecracker)

## Running

Requires [`just`](https://github.com/casey/just). Bare-metal Linux x86_64 with `/dev/kvm`.

```bash
just install                  # install all runtimes
just setup boot-time          # build this bench's artifacts
just bench boot-time          # run the benchmark
```

Don't have `just`? Each recipe is a shell command; read the relevant `justfile` and copy the lines you need.

## Contributing

- **A new runtime:** add `runtimes/<your-runtime>/install.sh`. For each bench you want it measured in, add `benches/<bench>/adapters/<your-runtime>/` with the glue that bench needs (init, config, etc.).
- **A new bench:** add `benches/<bench>/` with its own `justfile`, `bench.py`, `adapters/`, and `results/`. Mirror `benches/boot-time/` as a starting point.
- **A fix or alternative configuration** for an existing runtime in an existing bench: PR to the relevant `benches/<bench>/adapters/<runtime>/` directory.

PRs that improve methodology or make a runtime look fairer are welcome.

## License

TBD.
