set shell := ["bash", "-uc"]

bench_dir := env_var_or_default("BENCH_DIR", env_var("HOME") + "/bench")

# Show available recipes
default:
    @just --list

# Install all runtimes
install: install-docker install-firecracker install-microsandbox

install-docker:
    bash runtimes/docker/install.sh

install-firecracker:
    bash runtimes/firecracker/install.sh

install-microsandbox:
    bash runtimes/microsandbox/install.sh

# Download the Firecracker kernel into BENCH_DIR (shared across pillars)
download-kernel:
    BENCH_DIR={{bench_dir}} bash runtimes/firecracker/kernel.sh

# Set up a pillar's local artifacts (e.g. `just setup boot-time`)
setup pillar:
    cd benches/{{pillar}} && just setup

# Run a pillar's benchmark (e.g. `just bench boot-time`)
bench pillar *args:
    cd benches/{{pillar}} && just bench {{args}}

# Wipe BENCH_DIR
clean:
    rm -rf {{bench_dir}}
