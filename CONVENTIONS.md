# Conventions

This document is the authoritative source for recurring implementation, layout, naming, style, security, testing, documentation and maintenance practices for Ubuntu Devcontainer Installers. It is independent of project phases, milestones and status.

## Interpretation and scope

### Authority

Define each recurring convention once here. Other documents may provide context or required outcomes, but must not restate these rules in forms that can drift.

When scope, terminology, support or contributor workflow changes, review all affected documentation and resolve contradictions and stale references in the same change.

### Requirement language

- **Must** and unqualified imperative statements are requirements. A deviation requires an approved policy or convention change.
- **Should** identifies the expected default. A deviation requires a documented reason.
- **May** identifies an optional practice.

Requirements apply only where their subject is relevant. Do not add empty sections, helpers or configuration solely to resemble another file.

### Product constraints

Follow the documented audience, use restriction and platform support contract. Target the documented Ubuntu release, qualify architecture claims, reject unsupported platforms and keep canonical installers independent of Dev Container Feature option handling.

## Repository-wide conventions

### Outcome and simplicity

Start from the required observable outcome and applicable documented requirements. Choose the simplest cohesive design that satisfies them completely and leaves the affected area clear, consistent and maintainable.

Simplicity means minimising conceptual and operational complexity, not minimising the diff, number of files changed or immediate implementation effort. Prefer a broader coordinated improvement when it produces a cleaner design or removes conflicting patterns, duplication or stale material. Do not expand scope without a concrete design or maintenance benefit.

- Prefer direct, readable content and focused responsibilities.
- Add abstraction or indirection only to remove demonstrated repetition or enforce an important invariant more clearly than direct code.
- Reuse established mechanisms; do not add speculative extension points, compatibility layers, fallbacks or parallel patterns.
- Keep exceptions narrow and explain them.
- Remove superseded material when compatibility requirements permit it.

### Convention precedence

Before creating or changing a file, inventory the relevant comparable files. Read the canonical example and any divergent examples; use searches or validation to check the complete set. Comparable files have the same role, such as installer entry points, installer READMEs, unit tests, integration Dockerfiles or test runners. Consistency applies within a file as well as across comparable files. Comparable sections, phases, helpers and scenarios in the same file must use the same established structure, naming, comment contract, error handling and validation approach. Do not mix equivalent inline and extracted implementations without a documented reason.

Apply conventions in this order:

1. explicit documented product requirements;
2. type-specific rules in `CONVENTIONS.md` or an approved template;
3. the current canonical pattern for comparable files;
4. the current canonical pattern for comparable sections, phases, helpers or scenarios within the file; and
5. the relevant language, ecosystem or tool convention.

Do not copy an existing pattern without confirming that it is current and consistent with higher-precedence rules. When comparable files conflict, identify the intended canonical pattern and either update all affected files in scope or document a bounded migration plan. Do not add another variation.

When no suitable convention exists, use the simplest established ecosystem practice that fits the repository. Add it here in the same change when it affects public structure, is reusable or is likely to recur. Do not codify inconsequential one-off choices.

For each recurring file type, define its required location, filename, section order and validation when the type is introduced more than once. Use the canonical order for relevant concerns and omit inapplicable sections. Prefer formatters, linters, schemas and focused validation over prose-only enforcement when practical.

### Naming and structure

Use one clear, descriptive name for each concept across code, configuration, documentation and tests. Reuse project vocabulary and avoid unexplained abbreviations or synonyms.

- Directories and general filenames: lowercase kebab-case.
- Bash variables and functions: lowercase `snake_case`.
- CLI options: lowercase kebab-case.
- Project environment variables: uppercase `SNAKE_CASE`.
- External identifiers: their ecosystem convention.
- Required filenames: their established form, such as `README.md`, `Dockerfile` and `install.sh`.

Name comparable files from the same components in the same order. Keep paths as shallow as ownership permits and reserve generic names such as `common` or `utils` for coherent shared responsibilities. Add a top-level directory only for a distinct recurring content class and document it in the repository layout.

Coordinate renames across all references. Published paths, options and identifiers are compatibility contracts. Preserve them unless an approved project versioning decision permits a documented breaking change.

### Currency and maintenance

Current means the latest stable version, syntax or practice compatible with the documented support contract. Prereleases require explicit support and tests.

Verify against official upstream documentation, release metadata and security notices or, for Ubuntu packages, official Ubuntu metadata. A separately trusted repository is authoritative only for content it supplies. Use secondary sources for discovery, then confirm against an authoritative source.

When changing a dependency or related behaviour:

- review affected versions, checksums, keys, repositories, URLs, options, base-image references and deprecations;
- update code, configuration, tests, examples, documentation and qualification metadata together;
- remove or mark obsolete and unsupported paths; and
- document intentional reproducibility pins and their update mechanism.

Do not use floating references where reproducibility matters or resolve uncontrolled versions during installation. Reliable automation should detect releases, moving images and deprecations, but adoption still requires compatibility review and tests.

Do not perform unrelated upgrades. Correct related stale references when safe; otherwise report bounded follow-up work.

## Installer implementation

### Code comments

Comment logical units of work, not code blocks merely because they are syntactic blocks. A logical unit is one or more adjacent statements that produce one coherent outcome and can be described by one purpose phrase.

In an executable script, a top-level phase begins when the lifecycle outcome changes—for example, from initialisation to input validation, prerequisite validation, discovery, execution, cleanup or result reporting. Declarations and setup belong to the phase they support. For a script with multiple phases, reading the file-purpose and phase comments in order must provide a concise outline of the script's flow. The file-purpose comment is an overview, not a substitute for phase comments.

Judge conditional comments for a future maintainer who is competent in Bash or Dockerfiles and familiar with these repository conventions, but has no knowledge of the author's reasoning. Do not use the current author, an automated agent or an end user as the reference reader.

A comment is required when either the file-type rules below require one or the reference maintainer cannot infer an important fact from local names, commands and control flow. Important facts include:

- why the unit exists or uses a non-obvious approach;
- a correctness, security or compatibility constraint;
- required ordering or a relationship to non-local code or state;
- a material side effect, failure condition or cleanup responsibility; and
- a workaround, external limitation or intentionally unusual implementation.

A conditional comment is not required when the reference maintainer can infer both the unit's purpose and every material constraint locally. If names or structure can make the code clear, improve them before adding explanatory prose. Never add a comment that only restates the next command.

Use these forms consistently in Bash programs and Dockerfiles:

- Use a concise, verb-led purpose phrase. It may be a sentence fragment and does not require terminal punctuation.
- Keep every comment line to at most 100 characters, including indentation and the comment prefix.
- Put one purpose or supporting point on each line. Do not wrap prose as an arbitrary paragraph.
- When one purpose phrase is insufficient, introduce a short list of parallel points:

  ```bash
  # Validate the request before changing system state
  # - Reject unsupported versions
  # - Preserve each package argument literally
  ```

- Keep a multi-line comment contiguous and place the complete comment block immediately above the unit it governs.
- Explain applicable constraints, non-obvious decisions, security boundaries, side effects, ordering and workarounds.
- Keep comments current with behaviour. A stale comment is a defect and must be corrected or removed in the same change.

Structured function-contract fields follow the same line-length and list rules.

### Bash programs

Every executable Bash program starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- Use `readonly` for immutable values and Bash arrays for ordered literal collections.
- Quote expansions and use `[[ ... ]]` for Bash conditionals.
- Use `printf` instead of implementation-specific `echo` behaviour.
- Pass `--` before positional values when supported.
- Do not depend on the caller's working directory.
- Return non-zero after a clear diagnostic when an operation cannot complete safely.

Format and lint new or changed shell code with:

```bash
shfmt -d -i 4 -ci <files...>
shellcheck --enable=all <files...>
```

Use repository wrappers instead when they are provided so local and CI behaviour remain identical.

Apply these Bash-specific commenting rules:

- Give every Bash file a purpose comment. Mention sourcing side effects when applicable.
- In an executable script with multiple top-level phases, give every phase an implementation block comment so the comments form an outline of the main flow.
- Apply the reference-maintainer test to nested blocks; their syntax alone does not require a comment.
- Document every shared-library function immediately above its definition.
- Use whitespace to make comment scope unambiguous:
  - A file-purpose comment is preceded and followed by one blank line.
  - A function contract is preceded by one blank line and immediately followed by its function definition without a blank line.
  - An implementation block comment is preceded by one blank line and immediately followed by the smallest block it governs without a blank line. Match the comment indentation to that block.
  - A control-flow heading is surrounded by one blank line. Control-flow headings apply until the next phase heading.
- In unit test programs, comment each logically distinct scenario. Describe expected behaviour or an important test constraint rather than setup commands or assertions.

For a shared-library function, use only the applicable fields from this form:

```bash
# Usage: sync_assets <source_dir> <remote_host> [--delete]
# Description: Sync local assets to a remote server through rsync
# Side Effects:
# - Modify files on the remote host
# - Create a local sync.log file
# Returns: 0 on success, 1 for a network failure, 2 when the source is absent
sync_assets() { ...
```

Use each field consistently:

- **Usage** lists required inputs and optional arguments.
- **Description** states the function's purpose and any material standard-output or standard-error behaviour.
- **Side Effects** identifies persistent or caller-visible state changes, such as modifying files, arrays or remote resources. Omit it when there are none.
- **Returns** lists exit statuses only. Do not use it to describe standard output or standard error.

Validate shared-library function contracts with the foundation comment-conformance test. The test rejects legacy contract fields, requires `Usage` and `Description` immediately above every shared-library function, and rejects output behaviour in `Returns`.

## Service adapters and runtime orchestration

The optional service interoperability contract uses the fixed provider directory `/usr/local/libexec/ubuntu-devcontainer-installers/services/`. Service identifiers must be lowercase kebab-case and must resolve only beneath that directory; registration must never accept an arbitrary executable path, generated shell code or executable drop-in discovery.

An eligible service installer must install one root-owned regular executable adapter with mode `0755` and no group or other write access. The adapter must accept literal `start`, `stop` and `status` operations. `start` and `stop` require root and return zero only after the owned service operation succeeds; `status` is read-only, usable by the development user and returns zero only after functional readiness is established. The installer must document the service name, adapter path, authority, readiness definition, owned state, logs and repeated operations.

Service installation and runtime policy are separate. Installing a service adapter must not install `container-services`, register the service or start it. `container-services register --service NAME` is consuming-Dockerfile policy and accepts one complete ordered list. Startup follows declaration order; rollback and normal shutdown use reverse order. Registration is atomic, idempotent for an identical list and rejects a different existing manifest.

Runtime programs must use the installed private copy of `lib/common.sh` rather than source the build payload or duplicate logging functions. All service and orchestration diagnostics use component-qualified `info`, `warning` and `error` messages with informational output on standard output and warnings and errors on standard error. Runtime state and manifests are root-owned and published atomically; readers such as `wait` and `status` never modify them.

A service-providing installer must have unit coverage for CLI, adapter trust and lifecycle parsing, integration coverage for installation, manual and automatic operation and failure paths, and packaged-artefact coverage for bundled-library resolution and installed runtime independence from the source or OCI payload.

### Dockerfiles

Every Dockerfile uses the current stable Dockerfile frontend and enables BuildKit checks as errors:

```dockerfile
# syntax=docker/dockerfile:1
# check=error=true
```

Keep parser directives at the start of the file and separate them from the first instruction with one blank line. The floating `:1` frontend selects the latest stable Dockerfile syntax in major version 1; do not use the experimental `labs` frontend without an approved need.

Apply these formatting and implementation rules:

- Use uppercase instruction names and JSON form where an instruction supports and benefits from it.
- In an Ubuntu stage that has shell-form `RUN` instructions, set `SHELL ["/bin/bash", "-euo", "pipefail", "-c"]` before the first such instruction. Do not rely on `/bin/sh` semantics for Bash commands.
- Keep a short, cohesive command on one `RUN` line. For a continued command chain, end each continued line with `\`, start each following command with `&&`, and indent continuation lines by four spaces.
- For continued arguments that are not commands, indent continuation lines by four spaces and preserve one literal argument per line where practical.
- Order operations to preserve useful cache boundaries without combining unrelated work solely to reduce layer count.
- Use `COPY`, not `ADD`, unless automatic archive extraction or remote-source behaviour is specifically required and documented.
- Use BuildKit features only through documented stable syntax, and verify changed Dockerfiles by building every affected target.

Canonical command-chain form:

```dockerfile
RUN command-one \
    && command-two \
    && command-three
```

Apply these Dockerfile-specific commenting rules:

- Give every stage a purpose comment. Precede the complete comment block with one blank line and place its `FROM` instruction immediately after the block.
- Place an implementation block comment before every filesystem layer-producing instruction, including every `RUN`, `COPY` and exceptional `ADD`. Precede the complete comment block with one blank line and place the instruction immediately after the block.
- Apply the reference-maintainer test to other instructions; their instruction type alone does not require a comment.
- Separate instructions and their associated comment blocks with one blank line. Keep tightly related parser directives together at the top.

Validate code comments with the foundation comment-conformance test. It enforces comment line length, structured shared-library contracts, Dockerfile parser directives, and stage and filesystem-layer comment placement.

### Installer layout and bundled paths

Installer entry points live at `installers/<installer>/install.sh`. Use this canonical order for applicable concerns:

1. constants, defaults and installer metadata;
2. bundled-library resolution and imports;
3. usage and installer-specific logging functions;
4. argument collection;
5. input and option-compatibility validation;
6. privilege, platform and prerequisite checks;
7. focused installation helpers; and
8. execution through `main`.

Invoke the entry point explicitly:

```bash
main "$@"
```

Keep the main control flow visible in the installer. Shared libraries may implement genuinely common logging, fatal errors, command checks, Ubuntu release checks, argument validation, APT lifecycle operations and temporary-resource handling; they must not become a framework that obscures installer behaviour.

Resolve bundled files relative to the installer:

```bash
readonly installer_dir="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
        pwd
)"
readonly repository_lib_dir="${installer_dir}/../../lib"
```

The source tree, integration context and OCI payload must preserve this relative layout. Do not source helpers from undeclared host locations.

### Command-line interfaces and validation

Every installer is an executable program with an explicit CLI.

- Support `--help` and exit successfully without changing state.
- Use `--version` only for the installer program's version.
- Name product selectors specifically, such as `--node-version` or `--python-version`.
- Use long, descriptive option names in lowercase kebab-case.
- Reject unknown options, missing values and incompatible combinations.
- Document defaults and whether each option may be repeated.
- Validate all arguments before changing system state where practical.
- Perform privilege, platform and prerequisite checks after argument validation.

Validate names, identifiers, versions, paths, URLs and numeric bounds with domain-specific rules. Distinguish omission from an intentionally empty value where empty input is supported. Check related conflicts before making the first system change.

Do not silently normalise an invalid request, ignore unsupported input or omit an unavailable package-manager control. Treat a value beginning with `-` as data only after the parser deliberately consumes it as an option value. Prefer narrow grammars or allowlists to broad denylists and test every rejection boundary.

The canonical array interface is a repeatable singular option:

```bash
install.sh \
    --package package-one \
    --package "package two"
```

Each occurrence adds one literal element. Do not perform implicit comma splitting, whitespace splitting, glob expansion, word expansion or shell evaluation. An attached `--package=value` form may be supported only with identical semantics.

A file option may support large collections. Its contract must define one literal value per line, ignore blank lines and avoid implicit comments or evaluation unless explicitly documented.

Do not add a generic expression language. A narrow expansion operation requires a demonstrated installer-specific need, documented grammar, bounded output and success and failure tests.

### Logging and diagnostics

Use installer-qualified diagnostics:

```text
<installer>: info: <message>
<installer>: warning: <message>
<installer>: error: <message>
```

Write progress information to standard output and warnings and errors to standard error. Errors must be concise, specific and actionable. A missing-prerequisite error must identify the prerequisite and required composition order.

Do not log credentials, tokens or secret values. Preserve enough command detail in retained test logs to diagnose failures without allowing verbose output to obscure the installer-qualified error.

### Temporary files and cleanup

Installers must create unique temporary files or directories with `mktemp`; they must not use the agent and test-log workspace as a shared installer runtime directory.

- Use an installer-identifying template where practical without making the path predictable.
- Quote temporary paths and use restrictive permissions for sensitive content.
- Clean resources on every exit path.
- Use a narrowly scoped `EXIT` trap when a temporary resource survives beyond one command.
- Do not reuse a predictable path owned by another process.
- Remove only resources that the installer created or explicitly owns.

### Dependencies and composition

Check prerequisites before changing state and fail with the required composition order. Do not install prerequisite packages or toolchains: leave their installation and layer ownership to the consuming Dockerfile and document supported composition examples. An installer may install only packages that directly provide its documented outcome; repository-bootstrap tools and dependencies shared with other installers remain explicit prerequisites.

### Repeated invocation

Declare one behaviour in the installer README: idempotent, replace, multi-instance or single-instance. Expose collision-relevant values, test both the declared outcome and conflicts, and never overwrite a differently configured invocation accidentally.

## Security and package management

### Security baseline

Installer implementations must fail closed: a failed verification or secure operation must produce an actionable error rather than an insecure fallback.

Never evaluate caller-provided shell expressions. Risk acceptance must not be inferred from environment variables, system state, missing verification metadata or dependency availability.

### Controlled-risk implementation

A controlled-risk capability is permitted only when its development use is legitimate, it has been explicitly reviewed, and it remains disabled by default. Implement it consistently:

- use a specific `--allow-<risk>` option rather than an ambiguous option such as `--force`;
- identify the exceptional behaviour in `--help`;
- scope the exception to the smallest operation;
- immediately before that operation, emit an installer-qualified warning that identifies the weakened protection, practical consequence and safer alternative or mitigation; and
- test the secure default, required opt-in, warning text, advice and enabled result.

A generic message such as `unsafe mode enabled` is insufficient.

### Network downloads and integrity

Use the trust mechanism appropriate to the source, including:

- signed Ubuntu or external APT repositories;
- pinned OCI or content digests;
- upstream-published cryptographic checksums;
- verified release signatures; or
- trusted package-manager signatures.

Use HTTPS where supported. Store APT signing keys in dedicated keyring files rather than deprecated global trusted-key stores. Download to a unique temporary location, verify before installation and remove temporary artefacts.

Each installer README must identify every network source, whether its URL is mutable, its trust mechanism and any controlled-risk exception. Test checksum, signature or digest failures where those controls are used.

### APT lifecycle

An installer that changes APT sources or installs packages owns a complete APT lifecycle for each invocation:

```bash
apt-get update

DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends -- \
    "${packages[@]}"

apt-get clean
rm -rf /var/lib/apt/lists/*
```

- Use `apt-get`, not `apt`, in non-interactive scripts.
- Avoid recommended packages unless required and documented.
- Fail when repository configuration is unsupported.
- Document repositories added to the image.
- Remove temporary key material.
- Do not share an APT update cache between independent installer invocations.
- Leave package lists and caches in an image-appropriate state on success.

### Minimum-release-age controls

Where supported, expose and document a configurable supply-chain delay with a secure default where practical. Verify package-manager support, pass literal values and fail clearly or require explicit disablement rather than silently omitting a requested control. Test defaults, explicit values, disablement and unsupported versions.

## Verification

Use Bash, ordinary Ubuntu commands, Docker and project-owned assertion helpers. Do not add a third-party shell test framework without an approved change.

### Unit tests

Unit suites live at `tests/unit/<suite>/`, and test programs use the `*-test.sh` suffix. Group installer tests under the installer name and shared-foundation tests under `foundation`. A test program must be executable, source project-owned helpers from `tests/lib/` where useful and return non-zero on failure.

Unit tests run inside the development container without changing its operating-system state. Cover pure behaviour, including:

- argument parsing and validation;
- repeatable array and file-list handling;
- help and version output;
- unknown, missing and incompatible options;
- bounded expansion operations, where present; and
- platform detection through injected inputs.

### Integration tests

Integration suites live at `tests/integration/<suite>/`. Each suite has a `Dockerfile` and a `targets.txt` manifest containing one non-blank Docker build target per line. Use lowercase kebab-case target names. Each target represents one state assumption and must be independently buildable from the repository root. A suite may provide an executable `run-target.sh` when assertions require a built image to run, such as daemon lifecycle tests. The integration runner invokes it with the image tag, target and three project resource labels after a successful build. The hook must ignore build-only targets, run containers with all three supplied labels and remove or use `--rm` for every runtime resource it creates.

Run every state-changing scenario in a fresh Ubuntu 26.04 image or independent build stage. Cover applicable behaviour, including:

- default and explicit installation;
- installed commands, versions, files, ownership and permissions;
- APT source configuration;
- prerequisite failure and invalid input;
- declared repeated-invocation behaviour;
- integrity failures;
- controlled-risk defaults, opt-in, warnings, advice and enabled behaviour; and
- unsupported-platform rejection.

A scenario may make multiple assertions about one resulting state. Different state assumptions require independent build targets.

### Completion criteria

An installer is complete when:

1. its source logic has been reviewed rather than copied blindly;
2. its public CLI, prerequisites and repeated-invocation behaviour are documented;
3. all inputs are validated before state changes where practical;
4. the documented platform contract is enforced;
5. success leaves the documented command and filesystem state;
6. failure is actionable and returns non-zero;
7. pure logic, installation behaviour and applicable negative cases are tested;
8. source-tree and packaged-layout tests pass where packaging is affected;
9. network sources, trust mechanisms and controlled-risk functionality are documented and tested; and
10. all relevant repository checks pass.

### Test interfaces and logs

Use the repository test entry points when available:

```bash
./scripts/test-unit.sh
./scripts/test-integration.sh
./scripts/test.sh
./scripts/clean-test-resources.sh
```

Run focused tests while iterating and all affected scenarios before completion. Test from the packaged OCI layout whenever packaging can affect the change.

The test runners accept suite names matching directories under `tests/unit/` and `tests/integration/`; the integration runner additionally accepts one target from the selected suite's `targets.txt`. Keep detailed failures under `/tmp/ubuntu-devcontainer-installers/` and terminal output concise. This path is for development and test logs, not installer runtime temporary files.

### Docker resources

All integration resources use the inner Docker daemon and carry these labels:

```text
org.opencontainers.image.source=<repository>
io.github.serialprimate.project=ubuntu-devcontainer-installers
io.github.serialprimate.test-run=<unique-run-id>
```

Include a unique run identifier in image tags, container names and network names. Routine cleanup must select only project-labelled resources and must not run `docker system prune`. It may also remove anonymous volumes attached exclusively to a selected project-labelled container when removing that container with `docker container rm --volumes`; this association is the ownership boundary for volumes that Docker cannot label during anonymous creation. A whole-daemon maintenance command must be explicit and warn before acting.

Tests must pass against a clean inner daemon. Cached or persistent Docker state may improve local performance but must not be a correctness dependency.

## Documentation and packaging

### Repository documentation

Keep documentation current in the same change as behaviour. The repository README must describe current purpose, support, availability and usage accurately rather than presenting planned functionality as available.

Examples must use supported interfaces, remain executable where practical and avoid floating versions where reproducibility matters. A complete-file or canonical code example must follow the same applicable conventions as repository code. A focused fragment may omit unrelated boilerplate, but its surrounding text must identify it as a fragment and it must remain valid in the stated context. Do not present intentionally incomplete or non-conforming code as a preferred example. Use one term consistently for each concept and remove obsolete Dev Container Feature terminology or option contracts.

### Installer README structure

Use this canonical order for applicable sections:

1. Purpose
2. Supported platform
3. Prerequisites
4. Usage
5. Options
6. Installed files and commands
7. Repeated invocation
8. Network sources and integrity
9. Controlled-risk options
10. Examples
11. Known limitations

Omit **Controlled-risk options** when the installer has none. Other required sections may state that there are no applicable items but must not be omitted.

Document defaults, composition order and every installed command or material file. For each controlled-risk option, document its mechanism, likely consequences, appropriate development use cases, safer alternatives and mitigations.

### Markdown

New or changed Markdown must pass:

```bash
markdownlint-cli2 --config .markdownlint-cli2.jsonc <files/globs ...>
```

Use relative links for repository files and descriptive link text. Keep examples and option names aligned with implementation and tests.

Do not hard-wrap Markdown prose. Keep each paragraph and list item on one physical line so a focused edit does not require re-wrapping its surrounding text. Preserve line breaks only where Markdown syntax or intentional rendered formatting requires them, such as fenced code blocks, tables, block quotes, nested lists and hard line breaks.

### OCI packaging

Follow the documented OCI artefact, versioning and release-verification contract. Preserve the tested relative layout of `installers/` and `lib/`, build the non-runtime payload from `scratch`, and test scripts both in the source tree and after copying them from the candidate image.
