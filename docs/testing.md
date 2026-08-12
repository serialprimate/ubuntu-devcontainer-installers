# Testing

The project test suite uses Bash, ordinary Ubuntu commands, Docker and project-owned assertions. It has no third-party shell test framework.

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

Build and verify a local OCI candidate at the current revision:

```bash
revision="$(git rev-parse HEAD)"
./scripts/build-oci.sh ubuntu-devcontainer-installers:test 0.0.0 "${revision}"
./scripts/test-oci.sh ubuntu-devcontainer-installers:test 0.0.0 "${revision}"
```

The OCI verifier inspects release metadata and runs the `packaged-artefact` suite after copying the payload from the candidate into fresh Ubuntu 26.04 stages.

Detailed logs are retained under `/tmp/ubuntu-devcontainer-installers/`. The runners print the exact log path for a failed test.

## Unit suite layout

A unit suite lives at `tests/unit/<suite>/`. Each executable test is named `*-test.sh`, changes no operating-system state and exits non-zero on failure. Shared assertions live in `tests/lib/`.

## Integration suite layout

An integration suite contains:

- `tests/integration/<suite>/Dockerfile`; and
- `tests/integration/<suite>/targets.txt`, with one Docker build target per non-blank line.

Every target starts from a fresh Ubuntu 26.04 build stage. The runner builds targets independently with `--no-cache`, a unique image tag and project and test-run OCI labels.

## Cleanup

Remove resources carrying the project label:

```bash
./scripts/clean-test-resources.sh
```

Cleanup checks the Docker endpoint and operates only on containers, networks, volumes and images labelled `io.github.serialprimate.project=ubuntu-devcontainer-installers`. It does not run a daemon-wide prune or remove the unlabelled Ubuntu base image.
