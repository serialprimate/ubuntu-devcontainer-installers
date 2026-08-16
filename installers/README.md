# Installers

Each installer is an executable Bash program at `installers/<installer>/install.sh` with adjacent user documentation.

Available installers:

- [`apt-packages`](apt-packages/README.md) installs an explicit literal collection of Ubuntu packages;
- [`apt-python`](apt-python/README.md) installs Ubuntu Python with optional pip and virtual environment tooling;
- [`container-services`](container-services/README.md) installs the optional explicit runtime orchestrator for trusted service adapters;
- [`docker-in-docker`](docker-in-docker/README.md) installs Docker Engine with explicit nested-daemon lifecycle control and its optional service adapter;
- [`github-release`](github-release/README.md) installs one exact SHA-256-pinned raw GitHub Release executable;
- [`node`](node/README.md) installs a supported Node.js major from the signed NodeSource repository;
- [`npm-packages`](npm-packages/README.md) installs literal global npm registry packages with a configurable release-age delay;
- [`pipx`](pipx/README.md) installs a selected pipx release with a configurable release-age delay;
- [`pipx-packages`](pipx-packages/README.md) installs literal global PyPI applications with a configurable cooldown; and
- [`user`](user/README.md) establishes an explicit development user identity and optional, controlled-risk passwordless sudo access.

Copy the complete repository layout when consuming these installers so each entry point retains its `../../lib` relationship. The service orchestrator and adapter registration are available in release `0.5.0`. That release is available at `ghcr.io/serialprimate/ubuntu-devcontainer-installers` and preserves the layout under `/ubuntu-devcontainer-installers`. Prefer the immutable digest documented in the repository README.
