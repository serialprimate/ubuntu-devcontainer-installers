# Ubuntu Devcontainer Installers

Reusable Bash installers for constructing Ubuntu 26.04 development-container images.

> [!IMPORTANT]
> Milestone 5 is complete: the core system, Node.js, npm and pipx installers are available from the source tree. The full installer collection and OCI image have not yet been released.

## Intended audience and scope

This project is for expert software developers who can review installer behaviour, image-build logs, system changes and documented security trade-offs.

The installers are intended exclusively for development contexts, principally disposable or reproducible Dev Container images. They are not intended for:

- production systems or workloads;
- end-user desktops;
- general-purpose host provisioning; or
- operators who cannot assess the consequences of installer options.

The canonical product is a collection of small, explicit and tested Ubuntu installation programs. Dockerfiles, OCI distribution and any future Dev Container Features are consumption or packaging mechanisms around those programs.

## Support scope

The initial release will support:

- Ubuntu 26.04 LTS only;
- `linux/amd64` initially;
- Bash installers executed during a Docker BuildKit image build; and
- execution as `root`, unless an installer explicitly documents otherwise.

Installers must reject unsupported operating systems and Ubuntu releases rather than attempting best-effort installation. Ubuntu releases other than 26.04, non-Ubuntu distributions, production provisioning and guaranteed non-root installation are outside the initial scope.

## Installer status

The installers delivered through Milestone 5 are available from the source tree. The first release candidate is planned to contain:

| Installer | Purpose | Status |
| --- | --- | --- |
| [`apt-packages`](installers/apt-packages/README.md) | Install requested APT packages | Available in source |
| [`apt-python`](installers/apt-python/README.md) | Install Ubuntu Python tooling | Available in source |
| [`node`](installers/node/README.md) | Install a selected supported Node.js version | Available in source |
| [`npm-packages`](installers/npm-packages/README.md) | Install explicit global npm packages | Available in source |
| [`pipx`](installers/pipx/README.md) | Install a selected pipx release | Available in source |
| [`pipx-packages`](installers/pipx-packages/README.md) | Install explicit pipx applications | Available in source |
| [`user`](installers/user/README.md) | Establish a development user, group and optional sudo access | Available in source |

The following installers are deferred until their dependencies or security contracts are established:

- `codex` and `pi`, pending evaluation after generic npm support;
- `playwright`, pending stable Node and npm installer contracts;
- `install-script`, as the second post-MVP milestone pending a reviewed integrity and controlled-risk contract; and
- a project-owned Docker-in-Docker installer, as the first post-MVP milestone.

A dedicated `search-cli-tools` installer is not planned. Search tools available through npm or pipx can be selected explicitly with the generic package installers. Script-only tools remain deferred until the post-MVP installation-script investigation determines whether a generic or tool-specific integrity-controlled installer is justified.

## Installer model

Each available installer is an executable Bash program with an explicit command-line interface. Installers:

- support `--help`;
- use `--version` only for the installer program's version;
- validate input and reject unknown options;
- verify Ubuntu 26.04 and required commands;
- emit consistent diagnostics and return non-zero on failure;
- resolve bundled libraries relative to their own location; and
- document their repeated-invocation behaviour as idempotent, replace, multi-instance or single-instance.

Array inputs use repeatable singular options, preserving each argument literally:

```bash
/opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
    --package ca-certificates \
    --package xz-utils
```

Installers do not infer or silently install unrelated prerequisite toolchains. For example, `npm-packages` requires Node.js and npm first, while `pipx` requires Ubuntu Python and virtual environment support.

## Security and controlled-risk functionality

Secure, integrity-checked behaviour is the default. Installer input is not evaluated as shell syntax, credentials must not be logged, and secrets must not be accepted through ordinary command-line arguments when they would be exposed in image history.

Because this project is restricted to expert developers in development contexts, an installer may offer narrowly scoped functionality that uses a materially risky or insecure implementation only when all of these safeguards apply:

- the functionality is disabled by default;
- a specific installer option is required to enable it intentionally;
- the option and installer documentation explain the mechanism, risks, consequences, safer alternatives and mitigations;
- the installer emits a prominent warning with actionable advice immediately before using the risky mechanism; and
- tests cover the secure default, required opt-in, warning and enabled behaviour.

Risky behaviour must never become an implicit fallback when a secure operation fails. See [`PROJECT.md`](PROJECT.md) and [`CONVENTIONS.md`](CONVENTIONS.md) for the complete policy.

## OCI consumption

The planned release artefact is one small `FROM scratch` OCI image containing the complete installer collection, shared libraries, documentation and licence. It is not a runtime image.

After the first release, a consuming Dockerfile will be able to copy the collection from a versioned image:

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

# Provides the versioned installer payload
FROM ghcr.io/serialprimate/ubuntu-devcontainer-installers:0.1.0 AS installers

# Builds the development image from the supported Ubuntu release
FROM ubuntu:26.04

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the complete payload while preserving bundled-library paths
COPY --from=installers \
    /ubuntu-devcontainer-installers \
    /opt/ubuntu-devcontainer-installers

# Installs explicit Node.js prerequisites before Node.js and npm packages
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh \
        --node-version 24 \
    && /opt/ubuntu-devcontainer-installers/installers/npm-packages/install.sh \
        --package typescript \
        --package eslint
```

For reproducible builds, use this digest-pinned `COPY` fragment:

```dockerfile
# Copies the digest-pinned payload while preserving bundled-library paths
COPY --from=ghcr.io/serialprimate/ubuntu-devcontainer-installers@sha256:<digest> \
    /ubuntu-devcontainer-installers \
    /opt/ubuntu-devcontainer-installers
```

An exact Semantic Versioning tag may be used when digest management is impractical. Reproducible examples will not use a floating `latest` tag.

## Versioning and release qualification

The collection uses one Semantic Versioning release version. During initial development, versions use `0.y.z`:

- patch releases contain compatible fixes, tests or documentation;
- minor releases add installers or backward-compatible options; and
- major releases may remove or incompatibly change documented installer behaviour.

A release must pass source-tree and packaged-artefact tests against Ubuntu 26.04. Qualification records the Ubuntu image digest, target architecture, Docker and BuildKit versions, repository commit and complete test result. The published OCI digest is the immutable release identity.

## Repository layout

The implementation foundation and available installers use this structure:

```text
installers/        Installer entry points and installer documentation
lib/               Shared Bash installer helpers
scripts/           Unit, integration and cleanup entry points
tests/lib/         Project-owned assertion helpers
tests/unit/        Tests for pure behaviour
tests/integration/ Fresh Ubuntu 26.04 container scenarios
docs/              Detailed project guides
```

Packaging entry points and individual installer directories will be added by their corresponding milestones.

Shared code remains small and must not obscure installer control flow. The packaged layout will preserve the same relative relationship between `installers/` and `lib/` that is tested in the source tree.

## Development and testing

Development takes place in an Ubuntu 26.04 Dev Container with Bash, Git, Docker CLI, Docker Buildx where needed, and a functioning Docker-in-Docker daemon. Before integration tests, verify the Docker endpoint:

```bash
docker info
```

Use these test interfaces:

```bash
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test.sh
./scripts/clean-test-resources.sh
```

Unit tests use Bash and project-owned assertion helpers without changing the development container's operating-system state. Integration targets run as independent, no-cache builds from Ubuntu 26.04. Test cleanup targets only project-labelled Docker resources and does not run `docker system prune`. See the [testing guide](docs/testing.md) for suite layout, selectors and logs.

## Contributing

Before changing installer behaviour:

1. read [`PROJECT.md`](PROJECT.md), [`CONVENTIONS.md`](CONVENTIONS.md) and [`AGENTS.md`](AGENTS.md);
2. preserve documented installer CLI compatibility unless the collection version permits a breaking change;
3. update documentation whenever behaviour, options, dependencies, network sources, integrity controls or risks change;
4. run the relevant unit and integration tests; and
5. report the commands run, results and impact on related installers or resources.

Implementation migration is intentionally greenfield. Only eligible installation logic and adapted top-level documentation from the predecessor repository may be reused; its Dev Container Feature packaging, metadata, generated documentation, tests, helpers, workflows and repository layout are not implementation starting points.

## Project status

Milestones 1 through 5 are complete. The documentation baseline, shared Bash helpers, dependency-free test harness and the `apt-packages`, `apt-python`, `user`, `node`, `npm-packages`, `pipx` and `pipx-packages` installers are available. OCI publication preparation is planned for Milestone 6. Installation-script handling is the second post-MVP milestone. The complete scope, milestones and acceptance criteria are defined in [`PROJECT.md`](PROJECT.md).
