# Service lifecycle and privilege implementation plan

## Status and authority

This plan implements the accepted design in [Service lifecycle and privilege in development containers](service-lifecycle-and-privilege.md). The design document defines the intended behaviour and boundaries; this plan itemises the coordinated code, test, documentation, packaging and profile changes required for the MVP.

The implementation is complete as one release-scoped feature and was published in release `0.5.0`. The public and private Dev Container profiles now consume its qualified immutable OCI digest.

## Required outcome

The MVP must let an expert consumer install one or more trusted service adapters, install `container-services`, register the adapters explicitly in declaration order and use a stable root entrypoint without granting the development user unrestricted passwordless sudo.

The canonical Dockerfile composition must support one layer:

```dockerfile
RUN /opt/ubuntu-devcontainer-installers/installers/docker-in-docker/install.sh \
    && /opt/ubuntu-devcontainer-installers/installers/container-services/install.sh \
    && container-services register \
        --service docker-in-docker

ENTRYPOINT ["container-services", "entrypoint", "--"]
```

Docker-in-Docker must remain fully usable through manual `start`, `stop` and `status` commands when `container-services` is not installed or no service is registered.

## MVP exclusions

Do not add the following in the MVP:

- automatic registration by a service installer;
- `--enable-entrypoint` or `--enable-auto-start` installer options;
- arbitrary adapter paths, executable drop-in discovery or generated shell code;
- third-party adapters;
- dependency metadata, topological sorting, parallel startup or parallel shutdown;
- internal startup, readiness or shutdown timeouts;
- automatic service restart;
- a new external process supervisor, package or service-manager dependency;
- a preconfigured runtime base image; or
- structured logging or timestamps.

## Fixed interfaces and paths

Confirm these paths during implementation before writing state-changing code. If a path must change for a demonstrated conflict, update the design document, installer documentation and every test together.

### Source files

Add:

- `installers/container-services/install.sh`: build-time installer entry point;
- `installers/container-services/README.md`: public installer contract;
- `installers/container-services/container-services`: bundled runtime command; and
- `installers/docker-in-docker/container-service`: trusted provider adapter that delegates literally to the existing lifecycle command.

Retain `installers/docker-in-docker/docker-in-docker` as the single service-specific lifecycle implementation used for manual and automatic operation.

### Installed runtime files

The `container-services` installer owns:

- `/usr/local/bin/container-services`;
- `/usr/local/libexec/ubuntu-devcontainer-installers/container-services/common.sh` as its private runtime copy of `lib/common.sh`;
- `/etc/ubuntu-devcontainer-installers/container-services/services` as the ordered registration manifest; and
- `/run/ubuntu-devcontainer-installers/container-services/` as runtime coordination state created at container startup.

The Docker-in-Docker installer owns:

- the existing `/usr/local/sbin/docker-in-docker` manual lifecycle command;
- `/usr/local/libexec/ubuntu-devcontainer-installers/services/docker-in-docker` as its provider adapter; and
- `/usr/local/libexec/ubuntu-devcontainer-installers/docker-in-docker/common.sh` as its private runtime copy of `lib/common.sh`.

The shared provider directory is a collection-level compatibility location. Installing an adapter there does not imply that `container-services` is installed or enabled.

### File security

All persistent directories and files must be root-owned. Directories and executable programs should use mode `0755`; manifests and private runtime libraries should use mode `0644`. Registration must reject a provider path that is absent, a symlink, not a regular executable file, not owned by root or writable by group or others.

Use unique temporary files in the destination's root-owned directory and an atomic rename for manifest and runtime-state publication. Never follow or replace a symlink. Validate all requested services before changing the existing manifest.

## `lib/common.sh` work

Update `lib/common.sh` without changing its public function names or diagnostic output:

1. Rename internal `installer_name` parameters to `component_name`.
2. Generalise function-contract descriptions from installer-qualified to component-qualified diagnostics.
3. Retain `log_info`, `log_warning`, `log_error`, `die`, `require_command` and `require_root` compatibility for every existing installer.
4. Keep informational output on standard output and warning and error output on standard error.
5. Do not add timestamps, global state or shell-option side effects.

Update `tests/unit/foundation/common-test.sh` to cover a runtime component name such as `container-services` while retaining exact stream and output assertions. Run all installer unit suites because every installer sources this library.

Each runtime installer copies `lib/common.sh` into its own installed support directory. Add focused tests proving that source-tree commands use the bundled library and installed commands continue working after the source or OCI payload path is removed.

## Dedicated `container-services` installer

### Installer CLI and validation

Implement `installers/container-services/install.sh` according to the canonical installer layout and README structure. It must:

- support only `--help` for the MVP;
- reject positional arguments, unknown options and repeated or combined `--help` input;
- validate arguments before privilege, platform and prerequisite checks;
- require root and Ubuntu 26.04 on `linux/amd64` consistently with the collection;
- require only ordinary Ubuntu commands already covered by the documented base prerequisites;
- perform no network access and install no Ubuntu package;
- install the runtime command and private common library atomically with fixed ownership and modes;
- reject a conflicting installed command, support directory, library or configuration path rather than overwrite it;
- be idempotent when installed files are canonical; and
- leave registration absent and start no service.

The installer must make `/usr/local/bin/container-services` immediately resolvable so `install.sh && container-services register ...` works in one `RUN` shell.

### Runtime CLI

Implement these exact top-level forms:

```text
container-services register --service NAME [--service NAME ...]
container-services entrypoint -- COMMAND [ARGUMENT ...]
container-services wait
container-services status
container-services --help
```

Apply collection CLI conventions:

- `--service` is repeatable and preserves declaration order;
- at least one service is required by `register`;
- service names use a narrow lowercase kebab-case grammar;
- duplicates, unknown operations, missing values and extra arguments are errors;
- values are passed literally without shell evaluation or splitting;
- `register` and `entrypoint` require root;
- `wait` and `status` must be usable by the development user; and
- invalid input returns the documented usage status before inspecting system state.

Document and test exact exit statuses. Use status `2` for CLI misuse and non-zero operational statuses that distinguish registration, startup/readiness and shutdown failures where callers need to act differently.

### Registration

`register` must:

1. Resolve each name only as `/usr/local/libexec/ubuntu-devcontainer-installers/services/NAME`.
2. Validate every adapter's type, ownership, mode and executability before writing state.
3. Emit an actionable missing-adapter diagnostic naming the installer that must run first where the mapping is known.
4. Write one literal service name per line with no comments, blank values or executable paths.
5. Treat one invocation as the complete desired ordered list.
6. Reject an existing different manifest instead of merging or replacing it implicitly.
7. Succeed idempotently for an identical manifest.
8. Log the final ordered registration once without exposing unrelated environment or command arguments.

The installer and `register` operation are separate contracts even when called in one Docker `RUN` layer.

### Entrypoint lifecycle

`entrypoint -- COMMAND...` must:

1. Require at least one main-command argument and preserve all arguments literally.
2. Fail if it is not root or another live orchestrator owns the runtime state.
3. Treat a missing registration manifest as a transparent no-services mode.
4. Invalidate stale runtime state before startup and publish `starting` state bound to the current orchestrator PID.
5. Invoke registered adapters with `start` in declaration order.
6. Publish `ready` atomically only after every `start` succeeds.
7. On startup failure, publish failure, invoke `stop` for each successfully started service in reverse order, and exit without launching the main command.
8. Launch and retain ownership of the main command without `eval`, `sh -c` or reconstructed arguments.
9. Reap child processes and handle `TERM` and `INT` while startup or the main command is active.
10. Forward the received termination signal to the main command and invoke every registered adapter's `stop` in reverse order.
11. Continue reverse shutdown after a service stop failure and retain an aggregate failure result.
12. Initiate reverse service shutdown when the main command exits normally or unsuccessfully.
13. Preserve a non-zero main-command result; when the main command succeeds, return a shutdown failure if one occurred.
14. Remove or mark runtime readiness state as stopped before exit where signal delivery permits it.

The MVP trusts adapter blocking behaviour and has no internal operation timeout. Tests must demonstrate that the outer runtime can still enforce its own stop timeout and forced termination.

### Runtime state, wait and aggregate status

Define a minimal, documented runtime-state format under `/run/ubuntu-devcontainer-installers/container-services/`. It must represent orchestrator identity and `starting`, `ready`, `failed` and stopped/absent states without trusting stale data from a previous invocation.

`wait` must:

- read but never modify state;
- wait quietly without an internal timeout while the matching live orchestrator is starting;
- fail if startup failed, state is malformed or stale, or the orchestrator disappeared;
- after ready state, invoke every adapter's `status` in declaration order;
- emit only one final ready, failure or no-services diagnostic; and
- succeed immediately with an explicit no-services diagnostic when no manifest exists.

`status` must:

- return immediately rather than wait;
- report each registered service once in declaration order;
- invoke all adapters even if one reports failure;
- return non-zero if the orchestrator is not ready or any adapter fails; and
- succeed with an explicit no-services diagnostic when no manifest exists.

Readers must not require root and must not be able to modify the manifest or runtime state.

### Logging

Use the installed private copy of `lib/common.sh`. `container-services` owns orchestration-level messages; adapters own service-specific messages. Preserve adapter stdout and stderr directly. Avoid duplicate generic errors unless orchestration context adds an actionable fact, such as the service position involved in rollback.

Log registration, ordered startup, ready state, rollback, main-command exit, ordered shutdown and lifecycle failures. Do not log every wait poll.

## Docker-in-Docker changes

### Installer and installed layout

Update `installers/docker-in-docker/install.sh` to install its provider adapter and private common library on every successful invocation, regardless of whether `container-services` exists. It must:

- add no dependency check for `container-services`;
- preserve the existing Docker package, repository and manual command outcomes;
- validate all new destination paths before APT or filesystem state changes where practical;
- install root-owned canonical files and reject conflicting files or unsafe path types;
- include the new files in idempotence and collision checks; and
- leave Docker stopped and unregistered.

The provider adapter should be a narrow executable that delegates the single literal `start`, `stop` or `status` argument to `/usr/local/sbin/docker-in-docker`. Do not duplicate Docker lifecycle logic in the adapter.

### Lifecycle contract

Update `installers/docker-in-docker/docker-in-docker` to conform fully to the shared adapter contract:

- retain exactly `start`, `stop`, `status` and `--help` for manual compatibility;
- source the project logging functions in bundled-source and installed-runtime layouts;
- use component name `docker-in-docker` and standard stream routing;
- keep `start` and `stop` root-only while allowing non-root `status`;
- make `start` return only after `docker info` proves functional readiness;
- make `status` verify managed process identity and successful Docker API access, not only PID identity;
- define and test repeated `start`, repeated `stop` and stopped `status` results;
- distinguish and safely remove installer-owned stale PID/socket state when no live conflicting daemon exists;
- continue rejecting a live unmanaged or host-mounted Docker socket; and
- retain the dedicated-volume and privileged-container checks.

Review all current diagnostics and tests affected by replacing private logging helpers with `lib/common.sh`.

### Existing Docker-in-Docker tests and qualification

Update:

- `tests/unit/docker-in-docker/cli-test.sh` for shared diagnostics, non-root status semantics, adapter CLI delegation and exact invalid-input statuses;
- `tests/integration/docker-in-docker/Dockerfile` for provider adapter and private library ownership, modes, collision checks, idempotence and stopped installation state;
- `tests/integration/docker-in-docker/targets.txt` with automatic-orchestration and stale-state scenarios as needed;
- `tests/integration/docker-in-docker/run-target.sh` for manual lifecycle, automatic startup, `wait`, aggregate status, graceful reverse shutdown, missing volume, conflicting socket, stale state and anonymous-volume cleanup; and
- `scripts/test-docker-in-docker.sh` so complete-suite qualification exercises the new automatic path while retaining at least one manual path.

Do not weaken the existing proof of a non-`vfs` storage driver, nested container execution, privileged requirement, dedicated volume requirement or `--rm` anonymous-volume cleanup.

## New test suites

### Unit suite

Add `tests/unit/container-services/` with executable `*-test.sh` programs covering pure behaviour without changing operating-system state:

- help and every CLI arity boundary;
- service-name grammar, missing values and duplicate declarations;
- literal argument and declaration-order preservation;
- manifest parsing and exact idempotence comparison;
- adapter path construction without arbitrary paths or traversal;
- ownership and mode validation through injected test paths or metadata;
- runtime-state parsing and stale/live identity decisions;
- exit-status precedence;
- component-qualified logging and stream routing; and
- quiet wait behaviour through injected state transitions.

Use project-owned assertions and temporary files under the top-level `tmp/` directory. Do not require root or mutate the development container.

### Integration suite

Add `tests/integration/container-services/Dockerfile`, `targets.txt` and an executable `run-target.sh` where runtime assertions are required. Use trusted fake service adapters to test orchestration independently of Docker-in-Docker.

Cover independent targets for:

- default installation and repeated installation;
- installation followed immediately by registration in the same `RUN`;
- missing adapter, duplicate registration, conflicting manifest and unsafe adapter rejection;
- ordered startup and aggregate status;
- reverse normal shutdown;
- reverse rollback after a middle service fails startup;
- continuation after one service fails shutdown;
- main-command argument preservation and exit-status precedence;
- signal forwarding and child reaping;
- non-root `wait` and `status` with read-only state;
- quiet wait during delayed startup;
- malformed and stale runtime state;
- no-registration entrypoint pass-through;
- no-services `wait` and `status`; and
- outer-runtime forced termination of a deliberately hanging trusted fake adapter, confirming the documented no-timeout limitation.

Every runtime container created by `run-target.sh` must carry all three project labels and use `--rm` or explicit labelled cleanup according to `CONVENTIONS.md`.

### Packaged artefact

Update `tests/integration/packaged-artefact/Dockerfile` to:

- include `container-services` in the exact installer directory list;
- verify modes for its bundled runtime command and all added Docker-in-Docker provider files;
- invoke the packaged `container-services/install.sh --help`;
- install `container-services` from the candidate payload;
- prove installed runtime commands no longer depend on `/opt/ubuntu-devcontainer-installers` by removing or omitting that payload before invocation;
- register a packaged Docker-in-Docker adapter after both installers run; and
- verify source-tree and candidate-payload relative paths remain equivalent.

Add packaged runtime execution only where it can preserve the packaged suite's resource and privilege constraints; otherwise rely on the qualified Docker-in-Docker runtime suite after proving candidate installation layout.

## Conventions and architecture

Update `CONVENTIONS.md` in the same implementation change with recurring rules for:

- the service provider directory and lowercase kebab-case service identifiers;
- mandatory `start`, `stop` and `status` adapter semantics;
- adapter ownership, mode, literal execution and documentation;
- separation of service installation from registration;
- declaration-order startup and reverse-order rollback/shutdown for the MVP;
- component-qualified rather than installer-only diagnostics;
- private installed copies of shared runtime libraries; and
- unit, integration and packaged-artifact coverage for service-providing installers.

Update `docs/architecture-decisions.md` to record:

- `container-services` as a dedicated optional installer in the collection release unit;
- service adapters as optional interoperability supplied independently by eligible installers;
- explicit registration as consuming-Dockerfile runtime policy;
- the stable entrypoint metadata boundary;
- why executable drop-ins, automatic installer registration and a preconfigured base image are excluded; and
- why declaration order is sufficient for the MVP.

Review the canonical installer layout and README conventions before implementation. Do not create a parallel runtime package outside `installers/container-services/`.

## Installer documentation

### New installer README

Create `installers/container-services/README.md` in the canonical section order. Document:

- purpose and Ubuntu 26.04 `linux/amd64` support;
- root installation and registration requirements;
- absence of network sources and external packages;
- installed commands, files, ownership and modes;
- complete `register`, `entrypoint`, `wait` and `status` contracts and exit statuses;
- complete-list registration and declaration ordering;
- idempotent installation and registration collision behaviour;
- the fixed provider directory and trust checks;
- runtime state, logging and no-timeout limitation;
- no-registration pass-through and manual-service behaviour;
- one-layer Dockerfile composition with Docker-in-Docker;
- `ENTRYPOINT` and Dev Container readiness configuration; and
- known exclusions and forced-termination behaviour.

### Docker-in-Docker README and threat model

Update `installers/docker-in-docker/README.md` to document:

- the always-installed provider adapter and private runtime common library;
- service name `docker-in-docker` and exact adapter path;
- `start`, `stop` and `status` authority and functional-readiness semantics;
- exact one-layer registration example after installing `container-services`;
- no hard dependency on or automatic registration with `container-services`;
- direct manual commands and acceptable elevation choices when unregistered;
- that unrestricted passwordless sudo is unnecessary for automatic management;
- stale-state recovery and registration/manual conflict behaviour; and
- logging paths and component-qualified diagnostics.

Update `docs/docker-in-docker-threat-model.md` for root entrypoint startup, non-root readiness and status, adapter trust, manifest integrity, orchestrator runtime state, graceful versus forced shutdown and the unchanged authority of the privileged container and Docker socket.

### Collection documentation

Update:

- `installers/README.md` to list `container-services` and describe optional registration;
- `README.md` installer status, explicit composition examples, security discussion, OCI payload description, repository layout and development-profile behaviour;
- `docs/testing.md` with the new suites, selectors and runtime qualification coverage; and
- release documentation or release notes only where the chosen release version requires it.

The feature is released in `0.5.0`; consuming profiles must use its exact version or immutable OCI digest.

## Development Container profiles

Update both `.devcontainer/public/` and `.devcontainer/private/` only after the qualified installer release is available:

### Dockerfiles

- update the installer OCI reference to the new immutable release digest;
- install Docker-in-Docker, install `container-services` and register `docker-in-docker`, preferably in one cohesive `RUN` chain;
- add the stable JSON-form `ENTRYPOINT ["container-services", "entrypoint", "--"]`;
- stop installing the `sudo` package solely for daemon startup;
- remove `--allow-passwordless-sudo` from the `user` installer invocation; and
- retain the `docker` supplementary group and all existing privilege, volume and tool installation requirements.

### Dev Container JSON

- replace `postStartCommand: "sudo docker-in-docker start"` with `postStartCommand: "container-services wait"`;
- add `waitFor: "postStartCommand"`;
- retain `remoteUser: "dev"` and do not set `containerUser: "dev"`, because the root entrypoint requires the container process user to remain root;
- retain privileged mode, anonymous Docker data volume and `--rm`; and
- verify private-profile mounts and environment handling remain unchanged.

The current profiles consume the published `0.5.1` immutable OCI digest, which fixes non-root Docker-in-Docker readiness checks. Do not point them at an unpublished tag or digest. Profile qualification and checked-in digest replacement are complete after the qualified release; future profile changes should use the same controlled candidate-image and Dev Container qualification path.

## Other pre-existing installer impacts

### `user`

Do not remove or change the public `--allow-passwordless-sudo` option: it remains an explicit controlled-risk capability for consumers with broader requirements. Update examples or cross-references only to clarify that automatic service management no longer requires it. Retain all existing secure-default, warning and integration coverage.

### Other installers

`apt-packages`, `apt-python`, `github-release`, `node`, `npm-packages`, `pipx` and `pipx-packages` provide no runtime service adapter in this MVP. Do not add empty adapters, registration options or `container-services` dependencies. Run their unit and integration tests because `lib/common.sh`, collection documentation and packaged-layout expectations change.

### OCI packaging and release tooling

The root `Dockerfile` already copies the complete `installers/` and `lib/` trees, so no new packaging instruction should be needed. Verify that the new installer and bundled executable modes survive the `FROM scratch` payload. Review `scripts/build-oci.sh`, `scripts/test-oci.sh`, CI and release workflows for assumptions about installer names; change them only where tests reveal an explicit list or qualification requirement.

No new network source, package dependency, external service or release unit is introduced.

## Verification sequence

Run focused checks while implementing, then the complete qualification:

```bash
./scripts/test-unit.sh foundation
./scripts/test-unit.sh container-services
./scripts/test-unit.sh docker-in-docker
./scripts/test-integration.sh container-services
./scripts/test-integration.sh docker-in-docker
./scripts/test-docker-in-docker.sh
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test.sh
./scripts/build-oci.sh <candidate arguments>
./scripts/test-oci.sh <candidate image and metadata arguments>
```

Use the exact current command interfaces from each script's `--help` or source when supplying candidate arguments. Also run:

```bash
shfmt -d -i 4 -ci <all changed shell files>
shellcheck --enable=all <all changed shell files>
markdownlint-cli2 --config .markdownlint-cli2.jsonc <all changed Markdown files>
git diff --check
```

Build every changed Dockerfile target. Qualify the candidate Dev Container profiles through the Dev Container CLI and supported editor, then run the complete project suite through the automatically managed nested daemon.

## Completion criteria

The feature is complete only when all of the following are true:

1. `container-services` is a documented, idempotent installer in the source tree and packaged OCI payload.
2. Installation plus registration works in one `RUN` after requested adapters are installed.
3. Registration is explicit, ordered, atomic and limited to trusted project adapters.
4. Docker-in-Docker installs its adapter unconditionally but has no dependency on or automatic registration with `container-services`.
5. Manual Docker-in-Docker lifecycle remains documented and tested without `container-services`.
6. Automatic startup, readiness, status, rollback, reverse shutdown, signal handling and main-command exit semantics are tested.
7. Component-qualified logging reuses `lib/common.sh` and satisfies exact stream conventions.
8. Runtime programs do not depend on the source tree or copied OCI payload after installation.
9. Public and private profiles require no unrestricted passwordless sudo for Docker-in-Docker startup.
10. Existing `user` controlled-risk behaviour and every unrelated installer remain compatible.
11. Source-tree, integration, nested-daemon, packaged-artifact and Dev Container qualification pass.
12. Architecture, conventions, installer documentation, threat model, testing guide and collection documentation agree with the implementation.
13. No unapproved dependency, service, mutable release reference or hidden runtime composition is introduced.
