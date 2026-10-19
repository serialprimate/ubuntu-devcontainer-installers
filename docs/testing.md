# Testing

The project test suite uses Bash, ordinary Ubuntu commands, Docker and project-owned assertions. It has no third-party shell test framework. [Conventions](../CONVENTIONS.md#verification) owns recurring test requirements and resource ownership; this guide owns concrete commands, suite mappings and profile qualification.

## Prerequisites

Unit tests require Bash and the ordinary development commands used by the runner. Integration tests additionally require a usable Docker endpoint:

```bash
docker info
```

Integration tests pull and report the resolved `ubuntu:26.04` image used for qualification. The initial qualified platform is `linux/amd64`.

## Commands

Run all tests:

```bash
./scripts/test.sh
```

Run only the foundation suite:

```bash
./scripts/test-unit.sh foundation
./scripts/test-integration.sh foundation
```

Run one integration target:

```bash
./scripts/test-integration.sh foundation clean-ubuntu-26-04
```

Run the complete suite through a freshly installed nested Docker daemon:

```bash
./scripts/test-docker-in-docker.sh
```

The complete `./scripts/test.sh` entry point includes this nested qualification once. Its inner invocation sets a recursion guard while still running every unit and integration suite through the installed daemon.

### OCI candidate verification

Build and verify a local development candidate at the current revision:

```bash
revision="$(git rev-parse HEAD)"
./scripts/build-oci.sh ubuntu-devcontainer-installers:test 0.0.0 "${revision}"
./scripts/test-oci.sh ubuntu-devcontainer-installers:test 0.0.0 "${revision}"
```

Both scripts accept exactly `IMAGE VERSION REVISION`: the candidate image reference, an exact Semantic Versioning version and a full 40-character Git commit SHA. `build-oci.sh` builds and loads one `linux/amd64` candidate with release metadata; `test-oci.sh` verifies that metadata and runs the `packaged-artefact` suite against the same image. Packaged scenarios copy only from the candidate, not source-tree fallback paths.

A development candidate is not a qualified release merely because its revision label names `HEAD`; uncommitted inputs may differ. Release candidates require the reviewed clean tagged checkout and approval gates in the [release guide](releasing.md).

Detailed logs are retained under the top-level `tmp/` directory. The runners print the exact log path for a failed test.

## Unit suite layout

A unit suite lives at `tests/unit/<suite>/`. Each executable test is named `*-test.sh`, changes no operating-system state and exits non-zero on failure. Shared assertions live in `tests/lib/`. The `container-services` suite covers service-name validation, literal argument and order handling, trusted fixed adapter paths, manifest idempotence, runtime-state identity and exit-status precedence without requiring root or mutating the development container. The `docker-in-docker` suite retains manual CLI coverage and covers adapter delegation and shared component diagnostics.

## Integration suite layout

An integration suite contains:

- `tests/integration/<suite>/Dockerfile`; and
- `tests/integration/<suite>/targets.txt`, with one Docker build target per non-blank line.

Every target starts from a fresh Ubuntu 26.04 build stage. The runner builds targets independently with `--no-cache`, a unique image tag and project and test-run OCI labels. A suite may add executable `run-target.sh` runtime assertions; the runner supplies the built image, target and required resource labels. The `container-services` suite uses trusted fake adapters to qualify ordered startup, readiness, rollback, reverse shutdown, signal forwarding, read-only non-root wait/status, stale state and the documented outer-runtime forced-termination limitation. Docker-in-Docker lifecycle assertions use this hook to run the installed image with the documented privilege and explicit startup and shutdown, retaining manual and automatic adapter paths.

## Service-lifecycle qualification

This procedure verifies changes to service adapters, orchestration, shared runtime logging or their consuming profiles. Start in the supported development environment with a usable Docker endpoint; follow the [service-verification requirements](../CONVENTIONS.md#service-verification) and the public contracts in the [container-services README](../installers/container-services/README.md) and [Docker-in-Docker README](../installers/docker-in-docker/README.md). A missing capability or failed assertion is a qualification limitation or defect, not a reason to weaken the intended contract.

### Suite and acceptance mappings

The service qualification scope includes:

- `tests/unit/foundation/`: unchanged shared-helper interfaces, component-qualified diagnostics and exact standard-output/error routing.
- `tests/unit/container-services/`: CLI arity, service-name grammar, duplicates, literal arguments and order, fixed adapter paths and trust checks, manifest comparison, state parsing, live/stale identity, exit precedence and quiet waiting with injected inputs.
- `tests/unit/docker-in-docker/`: manual CLI compatibility, adapter delegation, non-root status semantics and component diagnostics.
- `tests/integration/container-services/`: canonical installation and collisions, immediate same-layer registration, missing or unsafe providers, conflicting manifests, ordering, reverse rollback and shutdown, continuation after stop failure, literal main-command arguments, exit precedence, signal forwarding and child waiting, non-root read-only wait/status, delayed readiness, malformed/stale state and no-registration operation. The runtime hook also exercises a deliberately hanging trusted adapter and outer-runtime forced termination.
- `tests/integration/docker-in-docker/`: package and runtime-file ownership/modes, installation idempotence and stopped/unregistered state, prerequisites and unsupported-platform failures, manual and automatic lifecycle, stale-state recovery and startup rejection without the dedicated mount. Retain non-`vfs` storage, nested container execution, privileged-runtime requirements, socket-conflict rejection and proof that outer `--rm` removes the anonymous volume.
- `tests/integration/packaged-artefact/`: the exact installer collection, bundled executable modes and help, relative library resolution, candidate-installed orchestration and Docker adapter registration, and installed runtime independence after removing the copied OCI payload. Full daemon execution remains in the privileged Docker-in-Docker suite rather than adding privilege to payload-layout tests.

These mappings describe the acceptance scope, not a claim that the current revision has passed it. If a required case lacks an assertion, report it as a coverage gap rather than treating another passing scenario as equivalent evidence. Changes to `lib/common.sh` affect all installer suites, not just service consumers. Non-service installers must retain their existing contracts without empty adapters or orchestration dependencies, and the `user` installer's controlled-risk sudo behaviour remains independently covered.

### Command sequence and results

Use focused suites while iterating:

```bash
./scripts/test-unit.sh foundation container-services docker-in-docker
./scripts/test-integration.sh container-services
./scripts/test-integration.sh docker-in-docker
```

Before qualifying a service-lifecycle release, run the complete source-tree entry point `./scripts/test.sh` and the [OCI candidate verification](#oci-candidate-verification) against the same revision. The complete entry point already includes nested-daemon qualification; do not repeat that expensive run solely to duplicate evidence. Build every affected integration target and run applicable format/lint checks from [Conventions](../CONVENTIONS.md). Preserve logs, commands, resolved base-image identity, revision and any unverified cases for the [release qualification record](releasing.md#qualification-record). Stop on a failed gate, diagnose it and rerun affected verification after correction; no required gate or approval may be inferred from a different passing check.

### Development-profile qualification

Profile changes additionally need a controlled candidate build before replacing checked-in immutable references:

1. Build and verify the candidate OCI payload, then use a temporary copy of each affected profile with only its installer-image reference changed to that candidate. Keep temporary profile configuration and logs in ignored `tmp/`; preserve the intended build context and resolve profile-relative paths explicitly.
2. Build and start the candidate through the Dev Container CLI and supported editor. Retain the root container process user, non-root development user, preserved entrypoint, long-running image command, read-only readiness barrier, Docker group, privileged mode, anonymous data volume and `--rm` lifecycle. Verify any private-profile mounts and environment handling without recording secret values.
3. Verify automatic startup, non-root readiness and Docker access, graceful stop, and the complete project suite through the automatically managed nested daemon. Check fresh recreation and anonymous-volume removal. A profile build alone does not prove editor attachment or lifecycle behaviour.
4. Record which CLI/editor and profile were exercised, commands, results and remaining limitations. Do not claim qualification for an unavailable private profile or editor. Preserve required human approval gates.
5. Replace a checked-in installer reference only after the approved release is published and verified by immutable digest. Local candidate qualification does not authorise an unpublished reference, publication or broader profile changes.

## Cleanup

Remove resources carrying the project label:

```bash
./scripts/clean-test-resources.sh
```

Cleanup checks the Docker endpoint and operates only on containers, networks, volumes and images labelled `io.github.serialprimate.project=ubuntu-devcontainer-installers`. Removing a matching container also removes its attached anonymous volumes, including interrupted Docker-in-Docker qualification state. It does not run a daemon-wide prune or remove the unlabelled Ubuntu base image.
