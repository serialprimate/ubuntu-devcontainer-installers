# Ubuntu Devcontainer Installers

Reusable Bash installers for constructing Ubuntu 26.04 development-container images.

> [!IMPORTANT]
> Release `0.5.0` is available from GHCR. For reproducible builds, use its immutable digest rather than a mutable convenience tag.

## Motivation

Dev Container Features currently hide too much behind a short entry in `devcontainer.json`. Installation order, transitive dependencies, platform branches, security issues, merged metadata and installer side effects all influence the resulting image, but none are obvious at the point of use.

Specifically:

- **Composition is needlessly indirect.** The Feature specification requires tools to resolve hard dependencies, soft `installsAfter` relationships and user overrides. When those constraints do not determine an order, the tool chooses one it considers "optimal" according to the specified [Feature installation-order algorithm](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-features.md#installation-order).
- **Basic reuse remains incomplete.** Installing the same Feature more than once with different options has been an open request since 2022 ([devcontainers/spec#44](https://github.com/devcontainers/spec/issues/44)). Ordering use cases also remain awkward or unsupported ([devcontainers/spec#524](https://github.com/devcontainers/spec/issues/524)). These are not edge concerns for a composition system.
- **The portability model promotes complexity.** Official guidance expects Feature authors to detect operating systems and architectures and to select platform-specific installation paths ([authoring best practices](https://containers.dev/guide/feature-authoring-best-practices)). A large matrix of branches, fallbacks and subtly different outcomes is harder to maintain and audit.
- **Tool behaviour does not reliably match the standard.** Implementation gaps can remain open for years ([devcontainers/cli#210](https://github.com/devcontainers/cli/issues/210)). Stewardship of the community has not produced standards development or implementation convergence at a pace this project considers acceptable.
- **The net security posture is obscure.** Feature metadata is composed as well as installation code: one Feature can make the whole container privileged, while capabilities and security options are accumulated. The reviewer must inspect every Feature, its dependencies, metadata, scripts, network activity and the implementing tool to understand the result.
- **Feature artefacts are not auditable.** While the [Dev Container lockfile](https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-lockfile.md) pins resolved Feature artefacts and detects replacement, it does not establish source provenance, verify transitive downloads performed by installers, inventory resulting filesystem changes or summarise the effective privileges of the composition. Features can silently install unrelated and unexpected packages or toolchains. There is no standard end-to-end audit mechanism for answering the basic question: what did this set of Features do to the image?
- **Risk acceptance is not explicit.** Security-sensitive behaviour should not emerge from metadata merging, a fallback path or an undocumented script.

### The Alternative

Today, the alternative is intentionally plain: small Bash installers, explicit command-line contracts and a visible sequence of commands in the consuming Dockerfile. Each installer uses secure defaults and documents its prerequisites, network sources, integrity controls, installed files and repeated-invocation behaviour. The complete tested collection is portable between source-tree use and a digest-pinnable OCI payload, without requiring Dev Container tooling or configuration. The expert user controls dependency selection, versions, source, installation and Docker layer ownership. Most importantly, it is possible to review the complete installation sequence, transitive downloads, resulting filesystem changes and security posture of the image before it is built.

This approach is not perfect. It does not claim to make image construction safe by default. Installer defects, compromised upstreams, stale documentation and poor choices by consumers remain possible. It does, however, keep the important decisions where they can be seen, reviewed and changed by the person building the image.

## Intended audience and scope

This project is for expert software developers who can review installer behaviour, image-build logs, system changes and documented security trade-offs.

The installers are intended exclusively for development contexts, principally disposable or reproducible Dev Container images. They are not intended for:

- production systems or workloads;
- end-user desktops;
- general-purpose host provisioning; or
- operators who cannot assess the consequences of installer options.

The canonical product is a collection of small, explicit and tested Ubuntu installation programs. Dockerfiles, OCI distribution and Dev Container configuration are consumption or packaging mechanisms around those programs.

## Support scope

The current release supports:

- Ubuntu 26.04 LTS only;
- `linux/amd64`;
- Bash installers executed during a Docker BuildKit image build; and
- execution as `root`, unless an installer explicitly documents otherwise.

Installers must reject unsupported operating systems and Ubuntu releases rather than attempting best-effort installation. Ubuntu releases other than 26.04, non-Ubuntu distributions, production provisioning and guaranteed non-root installation are outside the support scope.

## Installer status

The current installer collection is available from the source tree and the published OCI image:

| Installer | Purpose | Status |
| --- | --- | --- |
| [`apt-packages`](installers/apt-packages/README.md) | Install requested APT packages | Released in 0.1.0 |
| [`container-services`](installers/container-services/README.md) | Explicitly orchestrate trusted co-located service adapters | Released in 0.5.0 |
| [`apt-python`](installers/apt-python/README.md) | Install Ubuntu Python tooling | Released in 0.1.0 |
| [`docker-in-docker`](installers/docker-in-docker/README.md) | Install an explicitly managed nested Docker daemon and optional service adapter | Updated in 0.5.0 |
| [`github-release`](installers/github-release/README.md) | Install an exact SHA-256-pinned raw GitHub Release executable | Released in 0.3.0 |
| [`node`](installers/node/README.md) | Install a selected supported Node.js version | Released in 0.1.0 |
| [`npm-packages`](installers/npm-packages/README.md) | Install explicit global npm packages | Updated in 0.4.0 |
| [`pipx`](installers/pipx/README.md) | Install a selected pipx release | Released in 0.1.0 |
| [`pipx-packages`](installers/pipx-packages/README.md) | Install explicit pipx applications | Released in 0.1.0 |
| [`user`](installers/user/README.md) | Establish a development user, group and optional sudo access | Released in 0.1.0 |

Tools available through npm or pipx can be selected explicitly with the generic package installers. Tools that publish raw GitHub Release executables can use the integrity-controlled `github-release` installer. Generic remote bootstrap-script execution is excluded because the [installation-script handling investigation](docs/install-script-investigation.md) found that pinning a bootstrap script does not verify mutable downstream downloads.

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

The released `0.5.0` collection provides an optional `container-services` orchestrator for justified co-location. Service installers provide manual lifecycle commands and trusted `start`, `stop` and `status` adapters independently; the consuming Dockerfile explicitly registers a complete ordered list. Installation never registers or starts a service.

## Security and controlled-risk functionality

Secure, integrity-checked behaviour is the default. Installer input is not evaluated as shell syntax, credentials must not be logged, and secrets must not be accepted through ordinary command-line arguments when they would be exposed in image history.

Because this project is restricted to expert developers in development contexts, an installer may offer narrowly scoped functionality that uses a materially risky or insecure implementation only when all of these safeguards apply:

- the functionality is disabled by default;
- a specific installer option is required to enable it intentionally;
- the option and installer documentation explain the mechanism, risks, consequences, safer alternatives and mitigations;
- the installer emits a prominent warning with actionable advice immediately before using the risky mechanism; and
- tests cover the secure default, required opt-in, warning and enabled behaviour.

Risky behaviour must never become an implicit fallback when a secure operation fails. See [`CONVENTIONS.md`](CONVENTIONS.md) for the complete policy. The Docker-in-Docker privilege boundary and residual risks are detailed in its [threat model](docs/docker-in-docker-threat-model.md).

## OCI consumption

The release artefact is one small `FROM scratch` OCI image containing the complete qualified installer collection, shared libraries, documentation and licence. It is not a runtime image. The `container-services` service-lifecycle implementation is included in the released `0.5.0` collection. Approved releases are published at `ghcr.io/serialprimate/ubuntu-devcontainer-installers` by GitHub Actions.

A consuming Dockerfile can copy the collection from the published exact version:

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

# Provides the versioned installer payload
FROM ghcr.io/serialprimate/ubuntu-devcontainer-installers:0.5.0 AS installers

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
COPY --from=ghcr.io/serialprimate/ubuntu-devcontainer-installers@sha256:2e0caf41b91ddd90e76587ae8a839a79bccbfeb875992f1c1b86eab2840fa868 \
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

The approved GitHub Release workflow publishes exact, minor and major tags from an exact SemVer Git tag. For example, `0.5.0` publishes `0.5.0`, `0.5` and `0`, all for the same verified image. It records the digest and source revision in the GitHub Release and attaches the full qualification report. See the [release guide](docs/releasing.md).

## Repository layout

The implementation foundation and available installers use this structure:

```text
installers/        Installer entry points and installer documentation
lib/               Shared Bash installer helpers
scripts/           Unit, integration and cleanup entry points
tests/lib/         Project-owned assertion helpers
tests/unit/        Tests for pure behaviour
tests/integration/ Fresh Ubuntu 26.04 container scenarios
Dockerfile         FROM scratch OCI packaging entry point
.github/workflows/ Continuous-integration and approved-release automation
docs/              Detailed project guides
```

The root `Dockerfile` preserves the tested relationship between installer entry points and shared libraries.

Shared code remains small and must not obscure installer control flow. Runtime service programs install private copies of the shared logger because the build payload need not remain present in a running image. The packaged layout will preserve the same relative relationship between `installers/` and `lib/` that is tested in the source tree. See the [architecture decisions](docs/architecture-decisions.md) for the rationale behind the product shape, composition model and release unit.

## Development and testing

Development takes place in an Ubuntu 26.04 Dev Container with Bash, Git, Docker CLI, Docker Buildx where needed, and a functioning Docker-in-Docker daemon. The public and private profiles consume the released `0.5.0` payload, use the root `container-services` entrypoint and wait for service readiness through a non-root lifecycle hook. Before integration tests, verify the Docker endpoint:

```bash
docker info
```

Use these test interfaces:

```bash
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test-docker-in-docker.sh
./scripts/test.sh
./scripts/clean-test-resources.sh
```

Unit tests use Bash and project-owned assertion helpers without changing the development container's operating-system state. Integration targets run as independent, no-cache builds from Ubuntu 26.04. Test cleanup targets only project-labelled Docker resources and does not run `docker system prune`. See the [testing guide](docs/testing.md) for suite layout, selectors and logs.

## Contributing

Before changing installer behaviour:

1. read [`CONVENTIONS.md`](CONVENTIONS.md), [`AGENTS.md`](AGENTS.md) and the applicable [architecture decisions](docs/architecture-decisions.md);
2. preserve documented installer CLI compatibility unless the collection version permits a breaking change;
3. update documentation whenever behaviour, options, dependencies, network sources, integrity controls or risks change;
4. run the relevant unit and integration tests; and
5. report the commands run, results and impact on related installers or resources.

Implementation migration is intentionally greenfield. Only eligible installation logic and adapted top-level documentation from the predecessor repository may be reused; its Dev Container Feature packaging, metadata, generated documentation, tests, helpers, workflows and repository layout are not implementation starting points.

## Project status

Releases `0.1.0`, `0.2.0`, `0.3.0`, `0.4.0` and `0.5.0` were produced by the approved workflow and are publicly available from GHCR by exact version, convenience tags and immutable digest. Release `0.2.0` added the Docker-in-Docker installer, release `0.3.0` added the narrow `github-release` artifact installer, release `0.4.0` updated the `npm-packages` installer with explicit package lifecycle-script opt-in, and release `0.5.0` added the `container-services` orchestrator and Docker-in-Docker service adapter. Generic installation-script execution is not supported because a pinned bootstrap script cannot guarantee transitive download integrity, and no unverified execution mode is approved.
