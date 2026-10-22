# Testing

The project test suite uses Bash, ordinary Ubuntu commands, Docker and project-owned assertions. It has no third-party shell test framework. [Conventions](../CONVENTIONS.md#verification) owns recurring test requirements and resource ownership; this guide owns concrete commands, suite mappings and profile qualification.

## Prerequisites

Test runners require Bash 5.1 or newer, `setsid` (from Ubuntu's `util-linux`) and ordinary development commands. The supported development container supplies these tools. Fast repository checks additionally use the existing `shfmt`, `shellcheck` and `markdownlint-cli2` tools. Integration tests additionally require a usable Docker endpoint:

```bash
docker info
```

Integration tests pull and report the resolved `ubuntu:26.04` image used for qualification. The initial qualified platform is `linux/amd64`.

## Commands

Run fast, Docker-free checks before committing, from any working directory (paths below assume the repository root):

```bash
./scripts/check.sh
./scripts/check.sh foundation playwright-deps
```

`check.sh` checks all tracked and non-ignored untracked Bash and Markdown files, then runs all unit suites or the selected unit suites. It never changes formatting or installs tooling. This is an explicit pre-commit command, not an automatically installed Git hook, and it does not establish integration or release qualification.

Run complete source and nested-daemon qualification:

```bash
./scripts/test.sh
```

Run all source tests without nested qualification, for an independently scheduled CI gate:

```bash
./scripts/test.sh --source
```

With suite selectors, `test.sh [--source] SUITE...` runs each selected suite's unit and integration tests without nested qualification, preserving the focused interface. `--source` does not weaken the default complete entry point or the separate OCI verification gate.

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

### Scheduling and output

Run independent tests with an explicit concurrency bound:

```bash
TEST_JOBS=2 ./scripts/test-integration.sh
TEST_JOBS=2 ./scripts/test-unit.sh
TEST_JOBS=2 ./scripts/test.sh
```

`TEST_JOBS` accepts integers from 1 to 32 and defaults to 1. The same bound is forwarded into nested qualification and applies to packaged targets through `test-oci.sh`. It bounds whole test lifecycles, including build, runtime assertions and cleanup, not individual BuildKit operations. Within `test-unit.sh` and `test-integration.sh`, suites and targets are discovered in stable order and all selectors are validated before workers start or Docker is contacted; invalid configuration returns 2. Ordinary test failures do not stop remaining tests in that runner, and any failure makes the runner return non-zero. After a failed integration target, the coordinator checks Docker health with a ten-second timeout. If that check fails, it stops launching targets, collects active worker results and counts unstarted targets as aborted rather than failed. Aborted targets also make the runner return non-zero; they have not been tested. Higher-level wrappers execute gates in sequence and stop on failure: for example, `test.sh foundation missing` completes the foundation gates before rejecting the later selector. Nested qualification reports inner failures as a failed qualification gate, not necessarily the inner exit status.

A single parent prints launch-order `START` lines with worker PIDs and active/maximum worker counts, then completion-order result lines, elapsed seconds, completed/total counts and final passed/failed/aborted totals. The completion counter is not a test's manifest position; overlapping tests can complete in any order. Workers never write directly to the terminal. Each has a separate named log in a unique directory under top-level `tmp/`; failures include the exact path, exit status and the last 40 log lines. Diagnostic lines are prefixed so test output cannot become GitHub workflow commands. Nested qualification streams its inner progress while retaining `qualification.log`, rather than remaining silent for the complete inner run. Nested log paths beginning `/source/tmp/` refer to the same repository's local `tmp/` directory through the source bind mount.

Use the serial default on constrained VMs. Try two workers only after measuring memory, disk and elapsed time on the intended machine, especially for browser and privileged nested-Docker scenarios. More workers can increase contention, network traffic and disk usage rather than improve throughput. Image-tag removal does not guarantee BuildKit cache removal. Cold builds and all existing qualification coverage remain mandatory; no result depends on a warm cache.

On INT or TERM, the coordinator terminates active worker process groups, allows two seconds for shutdown, then kills remaining group members and reaps workers. Workers and runtime hooks clean their owned resources on catchable exits. A daemon-side build can outlive its disconnected client, and forced termination cannot guarantee Docker cleanup. Do not run project-wide cleanup alongside active tests: it selects all project-labelled resources, including other runs. Inspect retained logs and use the documented cleanup command after runs have stopped.

### GitHub CI

Both CI and release workflows run `check.sh` before accepting qualification and read the repository Actions variable `TEST_JOBS`, falling back to 1 when it is unset. It has the same 1–32 validation as local execution. Keep it unset on unmeasured runners; increase it only after measuring the intended GitHub VM. The CI workflow schedules Docker-free checks, source integration, complete nested-daemon qualification and OCI candidate verification as separate jobs. Independent jobs can overlap on separate VMs without putting multiple heavy workloads on one constrained VM; GitHub concurrency quotas may queue them. The stable `Source and OCI verification` aggregate job succeeds only when every required job succeeds. The release workflow deliberately retains a single protected job: it runs static/unit checks, complete source and nested qualification, and packaged verification before publishing the same candidate. This keeps the approval boundary, local candidate identity and complete qualification logs together without introducing cross-job artifact transport. The configured worker bound applies to every release test phase, and the qualification report records it alongside static/unit, source and packaged results. See the [release guide](releasing.md) for approval and recovery requirements.

Failure tails appear directly in CI output. Full `tmp/` logs remain local to the runner; they are not uploaded as artifacts by this workflow. Automatic artifact upload would require approval for an additional action dependency. Local commands and CI share the same scripts and qualification scenarios; concurrency changes scheduling, not acceptance criteria.

## Unit suite layout

A unit suite lives at `tests/unit/<suite>/`. Each executable test is named `*-test.sh`, changes no operating-system state and exits non-zero on failure. Shared assertions live in `tests/lib/`. The `container-services` suite covers service-name validation, literal argument and order handling, trusted fixed adapter paths, manifest idempotence, runtime-state identity and exit-status precedence without requiring root or mutating the development container. The `docker-in-docker` suite retains manual CLI coverage and covers adapter delegation and shared component diagnostics.

## Integration suite layout

An integration suite contains:

- `tests/integration/<suite>/Dockerfile`; and
- `tests/integration/<suite>/targets.txt`, with one Docker build target per non-blank line.

Every target starts from a fresh Ubuntu 26.04 build stage. The runner builds targets independently with `--no-cache`, plain BuildKit logs, a unique image tag and project and test-run OCI labels. The shared scheduler lives in `tests/lib/test-runner.sh`; `tests/lib/integration-target.sh` owns one target's build, runtime assertions and image-tag cleanup. Add scenarios through the existing suite files and manifests rather than adding another scheduler. A suite may add executable `run-target.sh` runtime assertions; the runner supplies the built image, target and required resource labels. The `container-services` suite uses trusted fake adapters to qualify ordered startup, readiness, rollback, reverse shutdown, signal forwarding, read-only non-root wait/status, stale state and the documented outer-runtime forced-termination limitation. Docker-in-Docker lifecycle assertions use this hook to run the installed image with the documented privilege and explicit startup and shutdown, retaining manual and automatic adapter paths.

## Playwright dependency qualification

The `playwright-deps` suite qualifies the dependency-only Ubuntu installer separately from a minimal consuming project. The supported targets are Playwright `1.64.0` and `1.64.1` (default), Node.js 24, Ubuntu 26.04 and `linux/amd64`; Firefox, WebKit and the separately packaged `@playwright/cli` wrapper are not included. The [installer README](../installers/playwright-deps/README.md) owns supported targets, project workflows, storage and trust limitations.

Unit coverage verifies exact stable-version validation, unsupported-version diagnostics, the mapped default, duplicate options and default/explicit package-list equivalence using isolated recording libraries. It runs without changing the development host's package state.

Integration targets independently exercise default/explicit/repeated installation without Node.js, unchanged state on unsupported versions, unsupported OS/architecture, missing APT, APT refresh failure and non-root rejection. `expected-packages.txt` is an independent reviewed snapshot checked against installed package state, not an upstream resolver. When updating the profile, review and update that expectation alongside the source mapping.

The `separate-storage-success` and `package-storage-success` targets qualify 1.64.1; `separate-storage-1-64-0-success` and `package-storage-1-64-0-success` independently qualify retained 1.64.0 support. Each creates a non-root project with exact, locked local npm dependencies and installs both Chromium variants explicitly. The main `project/` fixture contains the default version's manifests and shared test code. `project-1-64-0/` retains only that version's original package manifest and lockfile, overlaid without duplicating scripts or tests. `PLAYWRIGHT_TEST_TARGET` in the qualification image must match all three resolved npm package versions; a newer shared APT profile or identical browser revision is not accepted as proof that the legacy npm version ran. The fixture's `project-playwright.cjs` helper resolves the local package and storage from its own project root; `playwright.config.cjs` and `playwright-cli.config.json` configure test and CLI modes independently. JavaScript and TypeScript interaction tests run against regular Chromium in new headless mode and Chromium Headless Shell. TypeScript is transformed by Playwright, not type-checked; no extra compiler or web framework is installed.

`verify-project.cjs` asserts the user and ownership, target versions, absence of global Playwright packages, actual browser launch paths and headless arguments, real CLI interaction and unconditional session close, path-mismatch failures and unchanged Ubuntu package state. Setup downloads npm packages and browser archives through their documented network sources. Browser tests and CLI sessions run in `RUN --network=none` steps using in-memory HTML, with no display server or external site. Launch diagnostics distinguish the executable paths rather than relying on test-project labels.

The separate-store target reinstalls npm dependencies and reruns checks with retained browsers. The package-store target demonstrates removal by `npm ci`, an actionable missing-browser failure without an automatic download, explicit reinstall and restored operation. All caches start empty. Diagnostic output and failed assertions are retained in the integration runner's existing per-target logs; test-only browser files stay inside disposable Docker images.

Run focused source checks and any complete browser target from the repository root:

```bash
./scripts/test-unit.sh foundation playwright-deps
./scripts/test-integration.sh playwright-deps
./scripts/test-integration.sh playwright-deps separate-storage-success
./scripts/test-integration.sh playwright-deps package-storage-success
./scripts/test-integration.sh playwright-deps separate-storage-1-64-0-success
./scripts/test-integration.sh playwright-deps package-storage-1-64-0-success
```

Use the [candidate verification commands](#oci-candidate-verification) for packaged coverage. The packaged suite verifies the exact payload set and executable mode plus `playwright-default` (1.64.1), `playwright-explicit` (retained 1.64.0) and `playwright-unsupported` (1.64.2 rejection), always invoking candidate-provided installers/libraries. It does not duplicate the full browser matrix or add browser binaries to the product payload. Run all affected targets and the complete source entry point before claiming implementation qualification; publication still follows the release guide.

For another proposed supported target, first review its Ubuntu dependency groups and package/transitive impact, obtain dependency approval where needed, and select matching exact npm fixture versions and source references. Preserve the release-age and package-script policies. Repeat the browser and CLI checks even if the Ubuntu package list is identical. Never infer version support from package names, a successful help invocation or a previously populated developer cache.

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
