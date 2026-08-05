# Ubuntu Devcontainer Installers — MVP Project Specification

This document defines the time-bounded MVP scope, product policies, milestones and acceptance criteria. Recurring repository practices are defined only in [`CONVENTIONS.md`](CONVENTIONS.md).

## 1. Project identity

**Repository name:** `ubuntu-devcontainer-installers`

**Purpose:** Develop, test, version and distribute reusable Ubuntu 26.04 LTS installation scripts that can be invoked directly from project Dev Container Dockerfiles, including multiple invocations of the same installer with different arguments.

The project salvages useful installation logic from the existing `ubuntu-devcontainer-features` repository while replacing its Feature-specific packaging, option handling, tests, repository structure and release process.

### 1.1 Intended audience and use context

This project is intended for expert users who are software developers and can evaluate installer behaviour, image-build logs and documented security trade-offs.

The installers are provided exclusively for development contexts, principally the construction of disposable or reproducible Dev Container images. They are not intended for production systems, production workloads, end-user desktops, general-purpose host provisioning or use by operators who cannot assess the consequences of the requested system changes.

This restricted audience and context permit the controlled-risk policy in section 9.1. They do not remove the requirement to provide secure defaults, minimise risk or communicate material security consequences clearly.

## 2. Desired outcome

The MVP is complete when a consuming project can:

1. reference a versioned installer OCI image;
2. copy its installer scripts into an Ubuntu 26.04 Dev Container image;
3. invoke an installer one or more times with explicit command-line arguments;
4. receive deterministic success or clear failure;
5. rely on each published installer having passed isolated tests in fresh Ubuntu 26.04 containers;
6. pin the installer collection by immutable OCI digest, with a human-readable release version also available.

Example target usage:

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

Recommended immutable `COPY` fragment:

```dockerfile
# Copies the digest-pinned payload while preserving bundled-library paths
COPY --from=ghcr.io/serialprimate/ubuntu-devcontainer-installers@sha256:<digest> \
    /ubuntu-devcontainer-installers \
    /opt/ubuntu-devcontainer-installers
```

## 3. Target platform

The MVP supports:

* Ubuntu 26.04 LTS only;
* OCI-compatible image builds using Docker BuildKit;
* Bash as the installer implementation language;
* execution during a Dockerfile build;
* execution as `root`, unless an installer explicitly documents otherwise;
* the architectures explicitly qualified by the test matrix.

Initial architecture target:

* `linux/amd64`.

Installers must reject unsupported operating systems or releases clearly rather than attempting a best-effort installation.

## 4. Development environment assumption

Development takes place inside a predefined Dev Container that already provides:

* Ubuntu 26.04 LTS;
* Bash;
* Git;
* Docker CLI;
* a functioning Docker-in-Docker daemon;
* Docker Buildx where required;
* the permissions required to run test containers.

The initial Dev Container may use:

```text
ghcr.io/devcontainers/features/docker-in-docker:4
```

This is a temporary bootstrap dependency and is not part of the installer runtime or published OCI artefact.

The project must not depend on the implementation details of that Feature. Project scripts may assume only that a usable Docker endpoint is available.

A prerequisite check must verify:

```bash
docker info
```

before integration tests are started.

## 5. Docker-in-Docker replacement direction

A project-owned Docker-in-Docker installer is a planned follow-on outcome.

It will eventually replace the external `docker-in-docker:4` Feature in this repository’s Dev Container configuration.

The replacement must prioritise:

* Ubuntu 26.04-specific behaviour;
* the smallest practical implementation;
* no automatic creation of host-persistent named volumes;
* Docker state scoped to the lifetime of the development container by default;
* explicit daemon startup and shutdown behaviour;
* clear privilege requirements;
* compatibility with the project’s own container integration tests.

It is not required to bootstrap the installer MVP because the project begins in a predefined environment where Docker-in-Docker already works.

The project-owned Docker-in-Docker installer must not replace the external Feature until it has:

1. been developed as an ordinary installer;
2. passed isolated installation tests;
3. passed daemon startup tests;
4. successfully run the complete project test suite through its installed daemon;
5. been used successfully in a separate qualification Dev Container configuration.

## 6. Source migration policy

The starting source repository is:

```text
https://github.com/serialprimate/ubuntu-devcontainer-features.git
```

The source repository has been cloned to `./tmp/ubuntu-devcontainer-features` for easy access and reference.

Only the following source content is eligible for reuse:

* each Feature’s `install.sh`;
* top-level Markdown documentation, filtered and adapted where relevant;
* the licence, subject to preserving attribution and licence requirements.

All other source content is excluded as an implementation starting point, including:

* `.devcontainer`;
* `.github`;
* existing CI workflows;
* Feature metadata;
* generated Feature documentation;
* Feature tests;
* Feature scenarios;
* helper scripts;
* release workflows;
* repository layout;
* Dev Container Feature packaging.

Excluded content may be examined to understand prior behaviour, but it must not be copied as the implementation basis of the new project.

## 7. Initial migration inventory

The source repository currently provides installation logic for:

| Source Feature     | MVP treatment                               |
| ------------------ | ------------------------------------------- |
| `apt-packages`     | Migrate and redesign                        |
| `apt-python`       | Migrate and redesign                        |
| `codex`            | Evaluate after generic npm support          |
| `install-script`   | Investigate as second post-MVP milestone    |
| `node`             | Migrate and redesign                        |
| `npm-packages`     | Migrate and redesign                        |
| `pi`               | Evaluate after generic npm support          |
| `pipx`             | Migrate and redesign                        |
| `pipx-packages`    | Migrate and redesign                        |
| `playwright`       | Evaluate after Node support                 |
| `search-cli-tools` | Document composition; omit installer        |
| `user`             | Migrate and redesign                        |

### 7.1 First release candidate set

The first usable installer collection must include:

* `apt-packages`;
* `apt-python`;
* `node`;
* `npm-packages`;
* `pipx`;
* `pipx-packages`;
* `user`.

These provide the broadest reusable foundation and exercise the important installer patterns:

* APT packages;
* external APT repositories;
* version selection;
* repeatable array arguments;
* dependency checks;
* npm package installation;
* pipx package installation;
* composed development-tool installation;
* user and group configuration required for a usable development container.

The `user` installer is part of the first release candidate because the collection would not provide a usable Dev Container foundation without usable non-root user configuration. Its requested UID and GID must be established inside the image so bind-mounted files retain compatible ownership between the development container and its external environment. This requires replacing a pre-existing default account, such as Ubuntu's `ubuntu` user, when it occupies the requested identity.

Examination of the source `user/install.sh` does not identify BuildKit-specific behaviour or Dev Container runtime coupling that would justify deferral. Its ordinary image-build operations—replacing a default user and group, creating the requested user and group, assigning supplementary groups and optionally configuring sudo—can be redesigned behind an explicit installer CLI and tested in fresh containers.

### 7.2 Deferred installer rationale

`install-script` is deferred to the second post-MVP milestone because fetching and executing arbitrary remote code is a high-risk primitive. The investigation must decide whether a generic installer is justified or a specific installer should be used for each demonstrated case. A future form must provide integrity controls where practical. Any unverified execution mode must comply with the controlled-risk policy in section 9.1 and must never be the default.

`search-cli-tools` is removed as a dedicated installer and from the first release candidate. Its npm and pipx applications can be selected explicitly through `npm-packages` and `pipx-packages` without additional installation behaviour. Tools that are available only through remote installation scripts remain outside the MVP pending the post-MVP `install-script` investigation.

`codex` and `pi` should initially be expressible through `npm-packages`. Dedicated wrappers should only be added if they provide meaningful validation, configuration or lifecycle behaviour beyond naming one npm package.

`playwright` should be reconsidered after Node and npm installation contracts stabilise.

## 8. Greenfield repository structure

The MVP establishes distinct locations for installer entry points and their documentation, shared libraries, project-owned tests and assertions, test and release scripts, OCI packaging, and supporting documentation. The implemented layout must preserve the tested relationship between `installers/` and `lib/` and follow the recurring location and naming rules in [`CONVENTIONS.md`](CONVENTIONS.md).

## 9. Installer design contract

Every installer is an executable Bash program with an explicit command-line interface. It must support `--help`; `--version`, when provided, identifies the installer program rather than selecting a product version. Product version selectors must have specific names.

Installers must validate inputs and reject unsupported requests before state changes where practical, enforce the supported platform, make prerequisites explicit, emit actionable failures, and preserve the security requirements in section 26. Detailed Bash, CLI, diagnostic, path-resolution, temporary-resource and APT implementation rules are owned by [`CONVENTIONS.md`](CONVENTIONS.md#installer-implementation).

### 9.1 Controlled-risk implementation policy

Secure, integrity-checked behaviour is the default. Because the intended users are expert developers and the installers are limited to development contexts, a reviewed installer may also offer functionality implemented with a strategy, technique or approach that is materially risky or insecure when that functionality has a legitimate development use.

Such functionality is admissible only when all of the following are true:

* it is disabled by default and can be enabled only through a specific, explicit installer option;
* the option name and help text make the exceptional nature of the behaviour apparent;
* the installer README documents the implementation, material risks and likely consequences, the circumstances in which use may be reasonable, and safer alternatives or mitigations;
* immediately before using the risky mechanism, the installer emits a prominent warning that identifies the risk and gives actionable advice appropriate to the operation;
* the implementation scopes the risky behaviour as narrowly as practical and does not weaken unrelated installer operations;
* omitting the option preserves the secure default path;
* tests verify the secure default, the required opt-in, the warning and advice, and the enabled behaviour; and
* the exception and its rationale receive explicit review as part of the installer design.

An environment variable, auto-detection or the mere availability of a dependency is not sufficient opt-in. Risk acceptance must be an intentional choice in the installer invocation. Warnings must not expose credentials or other secret values.

This policy is not a general waiver of the security requirements. In particular, installers must never evaluate caller-provided shell expressions, silently activate insecure behaviour, or log or accept secrets in the prohibited forms described in section 26.

## 10. Command-line array contract

The MVP public interface for array-valued input is a repeatable singular option in which every occurrence contributes one literal value. Large collections may also use a documented literal file input. Splitting, expansion and evaluation are not part of the interface. Detailed parsing and validation rules are defined in [`CONVENTIONS.md`](CONVENTIONS.md#command-line-interfaces-and-validation).

## 11. Dynamic expansion policy

The predecessor's arbitrary dynamic shell expansion is excluded from the MVP. A narrow expansion operation may be delivered only for a demonstrated installer-specific requirement with predictable, bounded and tested output; no caller input may be executed as shell syntax. Detailed interface requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#command-line-interfaces-and-validation).

## 12. Shared library policy

The MVP may provide small libraries for genuinely shared behaviour, but installers must remain independently understandable and the packaged artefact must contain all required code in its tested relative layout. Recurring layout and design rules are defined in [`CONVENTIONS.md`](CONVENTIONS.md#installer-layout-and-bundled-paths).

## 13. APT behaviour

Every APT-using installer must be independently reusable and leave a secure, image-appropriate result. The MVP does not share APT update state between independent installer invocations. Detailed package-management requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#apt-lifecycle).

## 14. Dependency contract

The consuming Dockerfile controls prerequisite installation, layer ownership and composition order. Installers must fail clearly when a prerequisite package or toolchain is absent rather than silently installing it; project documentation must provide supported composition examples. Recurring dependency-checking requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#dependencies-and-composition).

## 15. Idempotency and repeated invocation

Every delivered installer must define and test its repeated-invocation outcome and must not accidentally overwrite a differently configured invocation. Multi-instance interfaces must expose collision-relevant values. The behaviour categories and recurring documentation requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#repeated-invocation).

### 15.1 User installer safety

The `user` installer must provide explicit options for the username, UID, GID, login shell, repeatable supplementary groups and optional sudo configuration.

It must:

* run as root and fail clearly otherwise;
* validate names and numeric identifiers before changing account state;
* reject UID `0`, GID `0`, and any operation that would remove or modify the `root` account or group;
* inspect all user-name, group-name, UID and GID conflicts before making changes;
* remove a pre-existing non-root user that has the requested user name or UID, including a default account such as `ubuntu`, when it does not already match the requested identity;
* remove a pre-existing non-root group that has the requested group name or GID when it does not already match the requested identity and is no longer required by another account;
* establish the requested UID and GID so ownership of bind-mounted files is compatible with the external environment;
* define an idempotent outcome when the requested user and group already match;
* fail before partial replacement when a conflicting account or group cannot be removed safely, with an actionable diagnostic;
* document whether and when a replaced user's home directory is removed;
* require the requested shell and supplementary groups to exist rather than silently skipping them;
* write any sudoers entry with mode `0440` and validate it with `visudo` before completing;
* comply with the command-line secret restrictions in the security requirements.

The consuming Dockerfile remains responsible for setting `USER`, and Dev Container configuration remains responsible for selecting `remoteUser` or `containerUser`. These are consumption concerns, not behaviour for the installer to infer.

## 16. Testing principles

The MVP uses Bash, ordinary Ubuntu commands, Docker and project-owned assertion helpers rather than a third-party shell test framework. Pure behaviour is tested without changing development-container system state; every state-changing installer scenario is tested in an independent Ubuntu 26.04 image or build stage. Detailed coverage and suite-layout requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#verification).

## 17. Integration test pattern

Each distinct integration state must be represented by an independently buildable target. Tests must not require a tagged result unless a runtime assertion needs one. The canonical suite and target structure is defined in [`CONVENTIONS.md`](CONVENTIONS.md#integration-tests).

## 18. Docker test-resource isolation

MVP integration resources must be uniquely identifiable, support parallel runs and be isolated in the inner Docker daemon. Routine cleanup may remove only project-labelled resources and must never use `docker system prune`. Detailed naming, labelling and cleanup requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#docker-resources).

## 19. Docker-in-Docker state policy

While the external Docker-in-Docker Feature bootstraps development, tests must remain correct against a clean inner daemon and must not depend on its persistent volumes. The planned project-owned replacement defaults to ephemeral daemon state; persistent state is explicit opt-in configuration.

## 20. Test runner interface

The MVP provides these entry points:

```text
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test.sh
./scripts/clean-test-resources.sh
```

They must support focused selection where applicable, return non-zero on failure, keep terminal output concise, retain useful failure logs and avoid unrelated Docker resources. Detailed interface and logging conventions are defined in [`CONVENTIONS.md`](CONVENTIONS.md#test-interfaces-and-logs).

## 21. Base-image qualification

Development tests use:

```text
ubuntu:26.04
```

Release qualification records the resolved image digest.

A release report must capture:

* Ubuntu image tag;
* Ubuntu image digest;
* target architecture;
* Docker version;
* BuildKit or Buildx version where material;
* installer repository commit;
* complete test result.

Run scheduled tests against the moving `ubuntu:26.04` tag so upstream image changes are detected before the next project release.

## 22. OCI artefact design

The installer collection is published as a small OCI image containing scripts and documentation, not an executable runtime image.

Rejected OCI Dockerfile fragment:

```dockerfile
COPY installers /installers
COPY lib /lib
```

This fragment is intentionally non-conforming: it demonstrates the relative-path packaging error that the preferred design must avoid.

The shared libraries cannot be placed at `/lib` if installer scripts resolve them through a repository-relative `../../lib` path under `/installers`. The final layout must preserve the tested source relationship.

Preferred payload:

```text
/ubuntu-devcontainer-installers/
├── installers/
├── lib/
├── LICENSE
└── README.md
```

Preferred OCI Dockerfile:

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true

# Packages the non-runtime installer collection
FROM scratch

# Copies installer entry points into the stable payload root
COPY installers /ubuntu-devcontainer-installers/installers

# Preserves the source-tree relationship used for bundled-library resolution
COPY lib /ubuntu-devcontainer-installers/lib

# Includes collection-level legal and usage documentation
COPY LICENSE README.md /ubuntu-devcontainer-installers/
```

Consumer `COPY` fragment:

```dockerfile
# Copies the versioned payload while preserving bundled-library paths
COPY --from=ghcr.io/serialprimate/ubuntu-devcontainer-installers:0.1.0 \
    /ubuntu-devcontainer-installers \
    /opt/ubuntu-devcontainer-installers
```

## 23. Versioning

The installer collection uses Semantic Versioning.

During initial development:

```text
0.y.z
```

Version meanings:

* patch: compatible installer fixes, tests or documentation;
* minor: new installers or backward-compatible installer options;
* major: removal or incompatible change to an installer CLI or documented behaviour.

The collection has one release version.

Per-installer versions would add unnecessary release and consumption complexity to the MVP. The collection can adopt independent installer versioning later if release cadence demonstrates a need.

Every release must publish:

* an exact version tag, such as `0.1.0`;
* a minor convenience tag, such as `0.1`;
* optionally a major tag, such as `0`;
* an immutable OCI digest;
* source revision metadata.

Consumers should be instructed to pin either:

* the digest for maximum reproducibility; or
* an exact version tag where digest management is impractical.

A floating `latest` tag must not be used in reproducible examples.

## 24. Release verification

Before publication:

1. run all unit tests;
2. run all integration tests against Ubuntu 26.04;
3. build the candidate OCI image;
4. copy the installers from the candidate OCI image into fresh test images;
5. rerun representative integration tests from the packaged artefact;
6. verify expected files and permissions;
7. inspect OCI metadata;
8. record the generated digest.

The source-tree tests alone are insufficient because packaging errors could omit or relocate required libraries.

## 25. Documentation outcomes

The MVP documentation must:

* present current purpose, audience, support, availability and usage in `README.md`;
* document OCI consumption, version and digest pinning, composition and test commands;
* provide an installer README for every delivered installer; and
* keep implementation detail and planned functionality out of user-facing claims until available.

Installer READMEs must satisfy the permanent structure and content requirements in [`CONVENTIONS.md`](CONVENTIONS.md#installer-readme-structure).

## 26. Security requirements

Installers must never:

* use `eval` for input handling;
* interpolate caller input into shell programs or evaluate caller-provided shell expressions;
* silently enable risky or insecure behaviour;
* log credentials or tokens;
* accept secrets as ordinary command-line arguments where they would be exposed in image history.

By default, installers must not:

* pipe unverified network content directly into a shell;
* download from mutable URLs without an explicit trust decision;
* disable TLS verification;
* use world-writable installation paths;
* weaken permissions.

Remote binary or archive installation must use one or more appropriate integrity mechanisms by default:

* repository signature verification;
* published cryptographic checksums;
* pinned digests;
* trusted package-manager signatures.

A reviewed exception to these default security requirements is permitted only under the controlled-risk implementation policy in section 9.1. The exception must be necessary for specific development functionality, explicitly enabled by an installer option, documented, narrowly scoped and accompanied by a warning with actionable advice at installation time. Risky behaviour must not become an implicit fallback when verification or another secure operation fails.

The `install-script` migration remains deferred until an integrity contract, including any narrowly defined controlled-risk modes, is designed and reviewed.

## 27. Minimum-release-age controls

Where the underlying package manager supports them, the MVP should preserve configurable supply-chain delay capabilities relevant to npm, pip or pipx. Delivered controls and defaults must be supported by the selected package-manager version, documented and tested. Recurring implementation requirements are defined in [`CONVENTIONS.md`](CONVENTIONS.md#minimum-release-age-controls).

## 28. CI direction

The MVP repository should support CI, but the initial project definition does not require reproducing the source repository’s workflows.

A minimal CI implementation should:

* run unit tests;
* run integration tests using an isolated Docker daemon or ephemeral runner;
* build the OCI artefact;
* test the packaged artefact;
* publish only from an approved release event.

Untrusted pull-request code must not receive registry credentials.

Use ephemeral CI runners for release qualification. Docker-in-Docker inside the local Dev Container is primarily a reproducible development workflow, not a substitute for CI isolation.

## 29. Explicit non-goals

The MVP does not provide:

* Dev Container Features;
* Feature metadata generation;
* Feature test generation;
* cross-distribution support;
* support for Ubuntu releases other than 26.04;
* Docker Compose orchestration;
* a general package-management abstraction;
* production provisioning or production workload support;
* an arbitrary remote-script execution framework;
* a general shell expansion language;
* persistent Docker-in-Docker storage management;
* automatic dependency composition;
* a guaranteed non-root installation mode;
* per-installer OCI images;
* per-installer independent release versions.

## 30. Later-stage outcomes

Potential later work includes:

1. project-owned Docker-in-Docker installer;
2. migration of the repository Dev Container away from `docker-in-docker:4`;
3. Ubuntu `linux/arm64` qualification;
4. dedicated Codex and Pi installers where justified;
5. Playwright installer;
6. integrity-controlled remote installer or specific installer for a demonstrated script-only tool;
7. generated Dev Container Feature adapters;
8. generated Feature tests;
9. additional Ubuntu LTS releases;
10. per-installer OCI artefacts if consumers require smaller payloads.

Generated Features must remain adapters over the canonical installer scripts. They must not become a second implementation.

## 31. MVP milestones

### Milestone 1 — Documentation baseline and review gate

**Status:** Complete. `README.md`, `CONVENTIONS.md` and `AGENTS.md` have been explicitly reviewed and approved as the documentation baseline.

Outcome:

* initial `README.md` describing the intended product, scope and consumption model;
* initial `CONVENTIONS.md` defining implementation and testing conventions;
* update `AGENTS.md` if needed to guide automated contributors;
* explicit review and approval of those three documents.

This is a review gate. Milestone 2 and all installer implementation work must not begin until the initial documentation has been reviewed and approved. Documentation may evolve later with reviewed behaviour changes.

### Milestone 2 — Implementation foundation

**Status:** Complete. The shared libraries, dependency-free test harness and clean-container integration runner are implemented and verified.

Outcome:

* greenfield repository structure consistent with the approved documentation;
* common Bash helpers;
* dependency-free unit test harness;
* Docker prerequisite validation;
* integration test runner;
* clean Ubuntu 26.04 test target.

### Milestone 3 — Core system installers

**Status:** Complete. The APT package, Ubuntu Python and development-user installers are implemented, documented and verified in isolated Ubuntu 26.04 targets, including the initial packaged-layout scenario.

Outcome:

* `apt-packages`;
* `apt-python`;
* `user` with explicit UID, GID, group, shell and sudo behaviour;
* isolated success and failure tests;
* default-account replacement, collision safety and idempotency behaviour documented and tested;
* packaged-layout tests begun.

### Milestone 4 — Node and npm installers

**Status:** Complete. The Node.js and global npm package installers are implemented, documented and verified with version selection, release-age controls, prerequisite failures and multiple package sets.

Outcome:

* `node`;
* `npm-packages`;
* repeatable package options;
* version and minimum-release-age controls;
* prerequisite failure tests;
* multiple package-set scenarios.

### Milestone 5 — pipx installers

**Status:** Complete. The pipx and global pipx package installers are implemented, documented and verified on Ubuntu 26.04 with configurable release-age and cooldown controls.

Outcome:

* `pipx`;
* `pipx-packages`;
* supported age or cooldown controls;
* Ubuntu 26.04 compatibility explicitly tested;
* prerequisite composition documented.

### Milestone 6 — OCI publication candidate

Outcome:

* the complete first release candidate installer set from section 7.1;
* `FROM scratch` OCI image;
* source-tree and packaged-artefact tests;
* Semantic Versioning;
* release metadata;
* exact-version and digest-pinning examples;
* release candidate `0.1.0`.

### Post-MVP milestone 1 — Docker-in-Docker replacement investigation

Outcome:

* requirements and threat model;
* Ubuntu 26.04 Docker installation prototype;
* ephemeral daemon-storage implementation;
* daemon lifecycle tests;
* qualification plan for replacing the external Feature.

This work does not block `0.1.0`. It should begin before the MVP only if the external bootstrap Feature prevents reliable development or testing.

### Post-MVP milestone 2 — Installation-script handling investigation

Outcome:

* requirements and threat model for remote installation scripts executed during image builds;
* review of the predecessor `install-script` behaviour without reusing its dynamic shell evaluation;
* decision whether demonstrated script-only tools justify a generic installer or specific integrity-controlled installers;
* integrity contract covering immutable source selection, cryptographic digest verification, redirects, temporary resources, execution authority and failure handling;
* literal repeatable argument handling without splitting, expansion or evaluation;
* decision on whether environment assignment is required, including a design that does not expose secrets through ordinary command-line arguments or logs;
* controlled-risk contract for any explicitly enabled unverified mode, including warnings, actionable advice, narrow scope and secure-default preservation;
* documented repeated-invocation and composition behaviour;
* implementation and isolated tests for the approved general or specific design; and
* a representative composition scenario for any development tool that motivates implementation.

This work does not block `0.1.0`. A remote script must not be executed merely because its URL is HTTPS or version-looking; secure installation requires verification of the selected content. Any unverified mode requires explicit review and must satisfy section 9.1.

## 32. MVP acceptance criteria

The MVP is accepted when all of the following are true:

* the repository is developed inside the predefined Docker-in-Docker Dev Container;
* all supported installers explicitly target Ubuntu 26.04;
* every installer in the first release candidate set in section 7.1 is migrated, redesigned and included;
* installers accept command-line arguments rather than Feature option environment variables;
* array inputs use repeatable singular options;
* no installer uses arbitrary dynamic shell expansion;
* unit tests require no third-party test framework;
* every state-changing integration scenario uses a clean Ubuntu 26.04 container state;
* expected-success and expected-failure behaviour are tested;
* repeated invocation behaviour is tested and documented;
* project cleanup affects only project-labelled resources;
* an OCI installer image can be built from `scratch`;
* scripts copied from that OCI image pass packaged-artefact tests;
* a consumer Dockerfile can invoke the same installer multiple times;
* release documentation explains exact-version and digest pinning;
* project and installer documentation identify the expert-developer audience and development-only use restriction;
* every controlled-risk capability is disabled by default, requires an explicit installer option, is fully documented, emits appropriate warning and advice, and has tests for those guarantees;
* excluded Feature infrastructure has not been carried into the implementation;
* adapted source documentation no longer describes the project as a Feature collection;
* the source project’s licence and attribution obligations have been preserved.

## 33. Guiding principle

The canonical product is not a Dev Container Feature collection.

The canonical product is:

```text
small, explicit, tested Ubuntu installation programs for expert developers in development contexts
```

Dockerfiles, OCI distribution and any later Dev Container Features are consumption and packaging mechanisms around those programs. Secure behaviour remains the default; exceptional risk is intentional, explicit, documented and visible in installer logs.
