"""Per-runtime adapters for the fs benchmarks.

Each adapter encapsulates the lifecycle of one runtime (pull image, start
a long-running instance, exec guest code with iteration count, tear down).
The two bench scripts drive them through a uniform interface so per-runtime
details (e.g. Docker's `--tmpfs /tmp` for fair `/tmp` comparison, msb's
`create + exec + stop + remove` sequence) live in one discoverable place.

Compare with `benches/boot-time/adapters/`: those are shell scripts because
boot-time invokes runtimes as one-shot CLI calls. fs needs to inject guest
Python source per iteration and read back JSON, which is clumsy via shell;
hence Python modules here.
"""

from .docker import DockerAdapter
from .microsandbox import MicrosandboxAdapter

__all__ = ["DockerAdapter", "MicrosandboxAdapter"]
