# Playwright dependency installer implementation plan

## Status and outcome

The 1.64.1 extension is implemented, with 1.64.0 retained and 1.64.1 the default. Current development checks passed 18 unit programs, 69 normal integration targets, all 13 focused Playwright targets and eight candidate packaged-artefact targets. Both versions passed real non-root JavaScript/TypeScript tests, both Chromium headless modes, both storage lifecycles and embedded CLI sessions. Static review found no issues.

Additional nested-Docker qualification recorded 18 unit passes and 66 integration passes with three failures caused by Ubuntu index download/integrity errors. The existing npm-packages target passed a separate scoped retry on that daemon; the Playwright repeated-installation and retained-version separate-storage targets did not complete their nested checks. These failures establish an external repository limitation, not a demonstrated code/assertion defect, but the nested aggregate remains failed. Do not promote separate normal successes or the one retry into a clean nested aggregate. The source upgrade is complete with this verification limitation explicitly accepted; no further test runs are part of this change. Broader nested verification remains limited, and clean CI/release qualification is not waived. No verification requirements or security checks were weakened to obtain a pass.

Here, an Ubuntu index limitation means inconsistent package-repository metadata during `apt-get update`: the failed runs received HTTP 404 responses or compressed package lists whose sizes did not match the repository's advertised values. APT correctly refused those inputs before the relevant installation/assertion steps completed. APT suggested a mirror synchronization issue, but the underlying cause was not independently confirmed. This is not a Playwright compatibility, disk-capacity or npm release-age failure.

The original 1.64.0 delivery had completed 18 unit tests, 67 integration targets, complete nested-Docker qualification and eight packaged-artefact targets. Those historical results are not substituted for the current upgrade checks. These are development verification activities, not an approved release qualification record or publication announcement.

P6 remains pending release approval and publication. The retained plan records design and delivery scope; the installer README and testing guide own current interfaces and verification procedures. Published release `0.5.1` does not include this source-only feature. The approved initial scope is Chromium and its embedded CLI only, including regular Chromium in new headless mode and Chromium Headless Shell. Working-tree changes and the reviewed Chromium dependency set plus test-only npm/browser downloads have been approved. The initial baseline was Playwright 1.64.0 because 1.64.1 had not yet met the seven-day npm release-age control. The requested upgrade adds exact 1.64.1 support and makes it the default while retaining explicit 1.64.0 support; both map to the same reviewed Chromium package list. Publication, profile migration and any additional dependencies still require their applicable approvals.

The Chromium profile contains 33 direct packages. An APT resolution against the reviewed fresh Ubuntu 26.04 image selected 117 new packages, approximately 92 MB of downloads and 333 MB of installed space; these are baseline-specific observations, not fixed size guarantees. Firefox, WebKit and browser-selection options are deferred.

The intended outcome is a development image that supplies the Ubuntu dependencies needed by supported Playwright browsers, while each consuming project owns its Playwright npm packages, matching browser downloads and browser storage. No container-wide browser installation or dedicated browser-cache volume is required.

Plan-local identifiers are Design decisions (D), Implementation phases (P) and Acceptance criteria (A). Their identifiers remain stable if this plan is revised.

### Governing documents and ownership

[Conventions](../CONVENTIONS.md) remains authoritative for implementation, security, tests, documentation structure and packaging. The [repository README](../README.md) owns the product's support scope and current availability. [Architecture decisions](architecture-decisions.md) owns durable composition rationale, the [testing guide](testing.md) owns verification commands and suite mappings, and the [release guide](releasing.md) owns publication approval and evidence.

This plan owns the proposed feature boundary and delivery sequence. During implementation, move the final public interface and operational guidance into `installers/playwright-deps/README.md`, durable rationale into architecture documentation where necessary, and verification mappings into the testing guide. Do not leave this plan as a second current interface specification after delivery.

## Design and implications

### D1 — Separate image components from project-local components

The image supplies the reviewed Ubuntu browser dependency profile selected for a supported Playwright version through a new `playwright-deps` installer. The consuming Dockerfile separately composes Node.js, certificate tooling and a development user through existing installers where needed.

The project supplies its npm manifest and lockfile, Playwright packages, browser installation command, browser-path configuration and cleanup policy. Browser installation runs as the development user after project dependencies are installed, not as root during image construction.

The dependency installer does not require Node.js, npm or a project checkout: installing Ubuntu libraries does not use them. The complete project workflow does require Node.js and usable HTTPS certificate trust; examples must compose those explicitly rather than have `playwright-deps` install them indirectly.

**Implication:** no global Playwright npm package, `/ms-playwright` directory, browser-image stage, browser-cache volume, browser service, entrypoint or automatic project hook is introduced by this feature. Existing `node`, `npm-packages`, `user` and service installers retain their responsibilities and interfaces.

### D2 — Provide a focused installer rather than another package-management framework

Use `installers/playwright-deps/install.sh` and an adjacent README. Accept an optional `--playwright-version VERSION` selector exactly once, using a separate value argument. `--help` describes supported versions and the default without state changes. Reject unknown options, positional arguments, missing values, repeated selectors and invalid or unsupported versions before system changes.

The selector means “install the Ubuntu dependency profile reviewed and qualified for this exact Playwright release”; it does not install that npm package or its browsers. It identifies the underlying Playwright release, not the independently versioned `@playwright/cli` wrapper. Accept only exact stable `major.minor.patch` versions present in the bundled supported-version mapping. Do not accept ranges, partial versions, mutable tags, aliases, prereleases or a nearest-version fallback in the initial contract.

When the selector is omitted, use a documented qualification baseline fixed by that installer collection release. The default must itself be an explicitly supported version, never an upstream `latest` lookup. Log the resolved target version before installation. Consumers wanting their target to remain explicit across collection upgrades should specify the option in their Dockerfile.

[Feedback] A version selector does not inherently imply dynamic dependency resolution. The boundary is between selecting a reviewed local profile, which this design supports, and discovering or inferring dependencies during installation, which it excludes.

[Opinion] A dedicated installer is justified by a meaningful maintained outcome: it supplies and qualifies the browser dependency set, instead of requiring every consumer to recreate the mapping. A public package-file interface would be a reasonable smaller alternative, but this plan selects the dedicated installer so there is one documented entry point and one qualification owner. Do not deliver both interfaces without a demonstrated need.

### D3 — Map supported versions to reviewed dependency profiles

Support the two explicitly qualified Playwright versions, 1.64.0 and 1.64.1, through one shared Chromium dependency profile. The profile is the deduplicated union of the pinned upstream `tools` and `chromium` groups for Ubuntu 26.04 on `linux/amd64`, subject to review of each package's role and Ubuntu availability.

Keep the mapping and readable Bash package array in the installer, with concise source/version comments. A literal version-selection branch mapping both supported values to the shared array is sufficient; do not build a historical-profile registry, generated resolver, new shared framework or public metadata format. The approved 1.64.1 package list is identical to 1.64.0 and therefore reuses its profile instead of duplicating it. The supported-version mapping and the package profiles are distinct concerns: a shared list does not by itself qualify another version's browsers.

The approved initial delivery supports Chromium only, without a browser selector. This reduces image impact and qualification scope. Firefox and WebKit are not supported by this profile. A repeatable browser-selection interface can be considered when another browser is needed, preserving Chromium as the default; adding that interface and its dependency groups requires separate approval and qualification. Consumers using hand-selected packages through `apt-packages` must not imply those combinations are qualified by this feature.

Preserve the complete upstream tools + Chromium groups. Any exclusion from those selected groups must have a specific rationale and corresponding verification; deferring the Firefox and WebKit groups is the approved feature boundary, not a partial claim of their support. Tools such as Xvfb may support headless-display execution, but installing them does not supply a desktop, VNC service or a display session automatically.

### D4 — Keep package selection review-time, not install-time

Derive each approved profile from the relevant pinned upstream release's Ubuntu 26.04 dependency definitions. Confirm package names against official Ubuntu metadata and actual fresh-image installation. Use the existing `lib/apt.sh` helper for the complete APT lifecycle. All supported-version mappings and profiles ship with the installer collection; selection performs no upstream query, npm execution or automatic profile generation. Do not add repositories, bootstrap tools or security exceptions.

Playwright `1.64.1` is the new default, with explicit `1.64.0` support retained. On 2026-10-22 at approximately 06:40 UTC, npm registry timestamps showed that all three 1.64.1 packages were over seven days old. The youngest, `@playwright/test`, was published at 2026-10-14T11:58:13.696Z and became eligible at 2026-10-21T11:58:13.696Z. Its exact dependencies are `playwright@1.64.1` and `playwright-core@1.64.1`; the seven-day control and disabled lifecycle scripts remain unchanged.

Review of pinned commits 606ecd8b34bac100db32561b6278ffd76e5eb3cd (1.64.0) and cfe490d941f992655948eee8fd4fd94e1c4234bf (1.64.1) found identical Ubuntu tools + Chromium package groups and browser manifests. This introduces no new Ubuntu packages or network sources. Runtime qualification remains necessary for each npm release even though their browser binaries and system requirements match. Future changes update the default, supported mapping, source references, locked fixtures and documentation together; do not populate unrelated historical versions.

[Feedback] Do not scrape `playwright install --with-deps --dry-run` as a general runtime package-discovery API. In the reviewed `1.64.0` implementation, the dependency portion runs an APT simulation, reports missing packages rather than the full declared set, depends on local APT metadata and returns non-zero when packages are missing. Older releases printed a shell command instead. Neither output is a stable machine-readable dependency contract.

A maintainer may use version-specific dry-run checks as supplementary evidence in a disposable test image with refreshed APT metadata. Never evaluate their output as shell code, treat empty output as proof of completeness, or ignore every non-zero result. The installer itself must not invoke npm, npx or Playwright.

### D5 — Offer two project-owned browser storage patterns

Document both patterns without making the installer configure either one.

**Separate project directory:** use a Git-ignored project-root `ms-playwright/` directory. Set `PLAYWRIGHT_BROWSERS_PATH` to its absolute path during browser installation and every test or CLI execution. Derive the path from a known project root, not an arbitrary caller working directory. Browsers survive replacement of `node_modules`; deleting this directory resets them independently.

**Package-local directory:** set `PLAYWRIGHT_BROWSERS_PATH=0` during browser installation and execution. Playwright places browsers beneath the relevant `playwright-core` package's `.local-browsers` directory. Removing `node_modules`, including through `npm ci`, removes these browsers and requires subsequent installation again. Multiple resolved Playwright copies can have separate browser copies.

[Opinion] Present the separate directory as the example for retaining downloads across dependency reinstalls, and package-local storage as the simpler disposable alternative. Neither is a universal default imposed on consumers.

**Implications:** persistence follows the workspace mount; project-local storage alone does not make a disposable container filesystem persistent. Each project can inspect and remove its own storage, but identical downloads may be duplicated across projects. Runtime downloads do not change the built image, although they consume workspace or container-writable-layer space. Git ignoring does not exclude files from Docker build contexts: document `/ms-playwright/`, `node_modules/` and generated results in the consuming project's applicable `.dockerignore` as well as appropriate Git ignores. Avoid sharing a browser installation between Linux-container execution and a different host operating system.

For the separate directory, explain Playwright's reference tracking and automatic unused-browser removal. Leave garbage collection enabled initially; do not add `PLAYWRIGHT_SKIP_BROWSER_GC` or `--no-remove` by default. If consumers disable cleanup, they own the resulting disk-growth policy. `PLAYWRIGHT_BROWSERS_PATH` does not relocate branded Google Chrome or Microsoft Edge installations.

### D6 — Qualify project-local testing and CLI use explicitly

For each supported target, use the corresponding exact, reviewed `@playwright/test` version in a committed integration fixture lockfile and verify its resolved Playwright version agrees with the installer selector. It provides the ordinary `playwright` command and, in the candidate stable release, agent-oriented commands through `playwright cli`. Verify both a real test run and a CLI browser session; command help alone is insufficient. Shared package profiles do not remove version-specific qualification requirements.

The separate `@playwright/cli` package provides the `playwright-cli` executable. It can be installed project-locally, but is not required for the embedded CLI workflow. Do not present the packages as identical or promise all wrapper-specific functionality through the embedded command.

[Feedback] Registry metadata checked during planning shows `@playwright/cli@0.1.22` depends on `playwright` and `playwright-core` version `1.64.0-alpha-1790635538000`. A stable-looking wrapper version therefore does not establish a stable underlying Playwright dependency or matching browsers. Initial runtime qualification targets the stable test package and its embedded CLI. Claim support for a separately packaged CLI version only after reviewing its resolved dependencies, obtaining any required prerelease approval and running the same browser-session checks. If that requires selecting a prerelease Playwright target, explicitly revise the initial stable-only contract in D2 before adding support; do not pass the wrapper version or silently map its alpha dependency to a stable target. Otherwise document local installability without claiming that version is qualified.

Configure the CLI independently of Playwright Test to use the project-installed regular bundled Chromium in new headless mode, as specified in D9. In the reviewed implementation, an unconfigured CLI can select branded Chrome instead. Do not assume the CLI reads `playwright.config` or that its browser option names map identically to Playwright Test channels. Validate the exact CLI configuration and command against the selected target, record the actual resolved browser and headless mode through supported launch diagnostics, and do not substitute an arbitrary executable path to bypass revision matching.

### D7 — Preserve the privilege and integrity boundaries

Only the dependency installer runs as root. Project npm installation and browser downloads run as the development user. Project browser commands omit `--with-deps`; missing system libraries require an image/dependency update, not automatic sudo or a privileged runtime installer.

The installer uses only configured APT repositories and their existing trust mechanisms. It does not download browser archives, execute remote bootstrap scripts, copy a Microsoft image or weaken TLS verification.

Project-local npm packages and browser downloads remain separate trust boundaries. npm lockfiles and registry integrity do not verify browser archives downloaded afterward. The reviewed upstream browser downloader uses HTTPS and transfer checks rather than pinned archive digests. Document this residual risk without implying that local storage resolves it or that this repository verifies those downloads. Consumers requiring stronger browser integrity need a separately reviewed acquisition mechanism; do not add an unverified-download opt-in to an installer that does not download browsers.

Use reviewed, locked test dependencies and disable npm lifecycle scripts in repository integration setup where the fixture does not need them. Verify that policy rather than silently enabling package scripts. Do not expose credentials or sensitive mounts to browser-download/test steps. Project-controlled executable storage must not be used as a trusted source by root or another security identity.

### D8 — Bound compatibility and avoid unnecessary scope

Qualify Ubuntu 26.04 on `linux/amd64`, a documented Node.js line and each exact Playwright version listed as supported. The initial Node.js qualification line is 24 LTS, and exact 1.64.0 and 1.64.1 support is maintained, without implying a supported version range. Adding another version requires a demonstrated consumer need, review and qualification; accepting a selector does not commit the project to indefinite historical support. Any later removal of a supported version or change to the default must be reviewed under collection compatibility/versioning policy and documented rather than silently retargeted.

A project can download a different browser revision without changing the image, but that revision may require different Ubuntu libraries or lack Ubuntu 26.04 support. The image-build selector checks only the version requested during that invocation; it cannot detect a project subsequently installing another version. Consumers must coordinate their explicit selector and project lockfile. Do not introduce project inspection, runtime version enforcement or compatibility inference to hide that responsibility, and do not claim compatibility with arbitrary past or future releases.

Do not add a new base image, service adapter, GUI stack, browser mirror, dependency-discovery service, shared cache, mandatory volume or automatic lifecycle hook. Do not add privileged mode, host IPC, extra capabilities or sandbox-disabling policy to consumption examples as an unexplained workaround. Explain applicable browser-runtime constraints and test under the documented development-container configuration; escalate any required privilege change for explicit review.

### D9 — Qualify explicit headless browser modes

Running in a container does not select Chromium's new headless mode. For the candidate release, Playwright's default headless Chromium path with no channel uses the separately distributed Chromium Headless Shell; selecting `channel: 'chromium'` with `headless: true` uses the regular bundled Chromium in new headless mode. Qualify both executable paths rather than treating them as interchangeable.

Configure the fixture's primary Chromium project as `chromium-new-headless`, with `browserName: 'chromium'`, `channel: 'chromium'` and `headless: true`. Add a small `chromium-headless-shell` smoke project with `browserName: 'chromium'`, `headless: true` and no channel, including no inherited channel. Minimal JavaScript and TypeScript interaction tests serve these two Chromium projects; this is installation/functionality coverage, not exhaustive browser conformance testing. Playwright's TypeScript transform does not provide type checking; projects requiring that independently select a local TypeScript compiler. No extra compiler dependency is needed for this fixture. Firefox and WebKit test projects are outside the initial scope.

Install both regular Chromium and Chromium Headless Shell in the project-local qualification environment, without Firefox or WebKit. Do not use `--only-shell` or `--no-shell` in the full qualification setup: each would exclude a required Chromium executable. These are browser-download choices, not options or additional browser downloads in the dependency installer. Run browser tests as the development user, and retain launch evidence sufficient to distinguish the regular Chromium and Headless Shell executable paths. Do not infer the launched mode solely from a test project's name.

The CLI qualification uses regular bundled Chromium in new headless mode, with explicit CLI-specific configuration and the same project-local storage setting. A separate CLI Headless Shell matrix is not required. These headless scenarios need no graphical desktop, display server or Xvfb wrapper; the upstream dependency profile may still include display-related packages. Headless mode does not itself establish sandbox isolation or justify additional container privileges.

## Implementation sequence

### P1 — Confirm inputs and approve the dependency baseline (completed)

Read the governing documents and comparable current files before editing implementation content. Start from `installers/apt-python/install.sh`, `installers/apt-packages/install.sh` and their tests as examples, not templates to copy blindly.

Check the working tree and obtain explicit approval before modifying a repository that already contains uncommitted work. The future presence of this plan as an uncommitted file is not an exception to that rule.

Review the candidate release's dependency definitions, platform support, browser-storage behaviour, regular Chromium versus Headless Shell selection, embedded CLI launch configuration and security notices using official sources. Revalidate D9's mode/channel mapping against the accepted target; resolve a release-specific difference explicitly rather than assuming all supported versions use identical defaults. Record the exact accepted baseline, default selector value, supported-version-to-profile mapping and source revision/reference in the installer documentation and source mapping comments. Approve each requested exact target and its mapping; 1.64.1 is an explicit reviewed addition, not inferred adjacent-patch support. Review the complete proposed Ubuntu package set, including transitive installation impact, and obtain approval for the new dependencies before installation or implementation that introduces them. No new registry, service or third-party testing framework is proposed.

**Output and gate:** an approved shared package profile, exact supported-version mappings and a documented default, plus any bounded exclusions and their rationale. If a package is unavailable, the platform is unsupported, a prerelease is needed or an extra privilege is required, stop and resolve that specific issue instead of adding a fallback. Do not proceed with an unqualified compatibility claim.

### P2 — Implement the dependency installer and its public contract (completed)

Create `installers/playwright-deps/install.sh` with executable mode and `installers/playwright-deps/README.md`. Follow Conventions for layout, comments, validation, diagnostics and README section order. Reuse the installer-relative `common.sh`, `platform.sh` and `apt.sh` libraries; add no shared helper unless genuinely necessary.

Parse the optional target version, validate its exact stable-version form and resolve it through the bundled supported-version mapping before any system changes. Omission selects the release-fixed default. Unsupported-version errors must identify the requested version and list the versions this collection supports; malformed values and missing or repeated selector arguments must have specific diagnostics. Do not silently normalise, round or substitute a version.

After argument validation and profile resolution, require root, the supported platform and the commands actually needed by platform checks and APT. Log the resolved target, then perform one complete APT lifecycle for its reviewed package array. Do not require or execute Node.js, npm or npx, create project directories, set runtime environment variables or configure user ownership.

Declare repeated invocation **idempotent for the selected profile**: another invocation ensures the selected packages are installed, independently refreshes and cleans APT state, and does not uninstall unrelated or previously installed packages. Default and explicit selection of the same target have the same result. Profiles select package requirements, not immutable Ubuntu package binaries; APT still uses available versions from configured repositories.

If additional profiles are introduced later, successive selections remain additive at the operating-system level, not isolated environments or a profile-switching/downgrade mechanism. Review cross-profile package conflicts before supporting that combination. Do not permit an invocation to satisfy its profile by silently removing packages required by another supported co-installed profile; reject a known conflict before APT changes or resolve the public contract explicitly. No persistent profile registry or multi-profile framework is needed for the initial one-profile implementation.

**Output and gate:** a minimal installer that deterministically selects a reviewed local profile and whose only installation changes are the documented Ubuntu dependency packages and normal APT lifecycle state. The README explicitly says no `playwright` command or browser executable is installed by this program.

### P3 — Add focused unit, integration and packaged-artefact coverage (completed)

Add `tests/unit/playwright-deps/cli-test.sh`, `tests/integration/playwright-deps/Dockerfile` and `tests/integration/playwright-deps/targets.txt`. Keep unit tests dependency-free and state changes inside isolated Docker scenarios. Store any project fixtures beneath the integration suite, with exact package selections and a reviewed lockfile. Use existing project-owned assertions and test discovery.

Cover the following independently buildable integration states, combining assertions only when they concern the same resulting state:

- **A1 — Installer interface and early failure:** help succeeds without root/APT activity and documents the release-fixed default and supported versions. Cover default resolution, explicit supported selection, missing/empty/repeated values, malformed versions, unsupported exact versions, ranges, partial versions, tags, prereleases, unknown options and positional arguments. Verify unsupported-version diagnostics list supported targets and that invalid requests reach no APT operation or upstream lookup. Unsupported platforms, missing prerequisites and non-root execution fail clearly. Use injected or recording commands for deterministic assertions without changing the development host; unit checks must also establish that the default is mapped and every supported target resolves to a non-empty profile.
- **A2 — Dependency-only installation:** independently verify default and explicit baseline selection on fresh Ubuntu 26.04 images without Node.js. Confirm both select the same target/profile, install the expected packages, clean APT metadata/caches, and do not install Node.js, npm, Playwright packages or browser-cache content. Distinguish pre-existing base-image content from installer effects. The recorded target and expected package list must agree with the reviewed mapping.
- **A3 — Repeated installation and APT failure:** repeated explicit invocations and a default-then-explicit invocation for the same target preserve the declared package outcome and cleanup. A controlled package-manager failure returns non-zero with actionable component-qualified diagnostics, without an insecure fallback. When another profile is added, add independent tests for its package selection and any supported cross-profile sequence or rejected conflict; do not fake additional production support just to test hypothetical branches.
- **A4 — Separate project-directory storage:** explicitly compose Node.js prerequisites, Node.js 24, the dependency installer with the corresponding `--playwright-version` value, and a development user. As that user, install the locked project dependencies, verify their resolved Playwright version matches the selector, and install matching browsers into project-local `ms-playwright/`. Run meaningful JavaScript and TypeScript local-content interaction tests in both headless fixture projects specified in D9: regular Chromium in new headless mode and default Chromium Headless Shell. Assert the executing user is non-root, confirm both Chromium executable paths from supported launch diagnostics, and use in-memory fixture HTML or a loopback test server rather than an external website. Confirm the local packages and browser files are user-owned, global Playwright packages are absent and reinstalling project npm dependencies preserves the separate browser store.
- **A5 — Package-local storage:** in an independent state, use `PLAYWRIGHT_BROWSERS_PATH=0`, verify installation under the resolved package, and run the same two-project Chromium headless matrix as A4, with non-root execution and Chromium executable-path evidence. Demonstrate that `npm ci` removes those browsers and that the documented browser-installation step restores working tests. Installation and execution must use the same storage mode, and setup must retain both Chromium variants as required by D9.
- **A6 — Functional project-local CLI:** use the selected target package's embedded CLI with its own explicit configuration for regular bundled Chromium in new headless mode, not merely a Playwright Test configuration. As the development user, open a deterministic page, perform an assertion or observable interaction, and close the session. Record the resolved browser executable and headless launch mode using supported diagnostics. Ensure cleanup also runs on failure. Exercise each documented storage pattern without requiring a display server; do not treat `--help` as a browser qualification.
- **A7 — Failure guidance and no hidden installation:** omit a browser installation in an independent fixture and confirm the documented installation step remedies the missing-browser condition. Verify the workflow does not install APT packages, invoke sudo or change global npm state. Demonstrate that a mode/path mismatch does not silently download or select a different browser through test-run commands.
- **A8 — Packaged execution:** extend `tests/integration/packaged-artefact/` expectations for the exact installer directory set, executable mode and help invocation. Add candidate-only targets that execute the dependency installer from the OCI payload without source-tree fallback, verify explicit supported selection and default resolution, and check package state, cleanup and bundled-library resolution. Verify an unsupported version is rejected through the packaged entry point before APT changes. Add the targets to its manifest.

For browser download/setup stages, network access is expected and must be reported. After setup, run meaningful browser tests without external network access where the supported BuildKit/test interface permits it; at minimum use exclusively local test content and record any inability to enforce network isolation. Never describe an unexecuted scenario as passing. Browser caches must be empty initially; persistent developer cache state is not evidence. Keep any fixture HTML or built-in Node.js loopback server inside the integration suite; no web application framework or external website is needed. Use Dockerfile test stages or the existing integration runner's `run-target.sh` hook where a running container is necessary, without introducing another orchestration framework. Packaged checks in A8 validate dependency-installer distribution and execution; they need not duplicate the complete browser matrix from A4–A6.

Test fixture browsers may occupy test images or runner storage. That is qualification data, not a change to the product's dependency-only payload or a reason to add browsers to consuming development images. Use the resource ownership, labels, logging and cleanup rules in Conventions.

Repeat the applicable browser and CLI qualification in A4–A6 for every version before adding it to the supported-version mapping, even when it shares a package profile with an existing version. A5–A7 fixtures must also select a documented supported target and resolve matching project packages. Qualification covers each exact supported target, not an inferred range. Keep the default 1.64.1 manifests in `project/` and the retained original 1.64.0 manifests in `project-1-64-0/`; share the same scripts/configuration and verify every resolved package against the image's explicit `PLAYWRIGHT_TEST_TARGET`.

**Output and gate:** A1–A8 have concrete assertions and passing evidence for every advertised supported version. An unavailable registry/CDN or Docker endpoint is an explicit verification limitation; diagnose it rather than weakening checks or changing versions opportunistically.

### P4 — Document complete consumption and maintenance workflows (completed)

Write the installer README as the canonical public contract and update the root README and `installers/README.md` to describe the installer accurately without presenting it as published before release. Add a brief durable image/project responsibility rationale to architecture documentation if needed; reference existing explicit-composition policy rather than duplicating it.

Document an executable consumption sequence: compose Node.js prerequisites and certificate trust, install Node.js and browser libraries explicitly, establish the development user, then install locked project dependencies and browsers as that user. Show `--playwright-version` explicitly in the image-build example and match it to the project's resolved Playwright version. Also document omission, the collection's fixed default, supported versions, rejection behaviour, and the distinction between a target selector and installing an npm package. The order between Node.js and `playwright-deps` is not a hard dependency; both must be present for the full workflow. Do not imply that the currently published installer digest already contains the new installer.

Provide complete, tested project-script examples for both storage patterns, separate from image-build fragments. Examples must retain the correct environment during installation, test execution and CLI execution, use a reviewed supported target and local command resolution, and clearly separate initial package selection from subsequent `npm ci`. Show a project-root-resolving wrapper where necessary rather than relying on arbitrary working directories. Explain that `npx --no-install` prevents opportunistic package installation but is not by itself proof that a command resolves locally; the fixtures must establish local resolution with no global Playwright command available.

Document Git/Docker exclusions, workspace persistence assumptions, space and cleanup trade-offs, platform-specific binaries, browser-version compatibility, Chrome-versus-Chromium selection, network/integrity boundaries and headed/display limitations from D5–D9. Explain new headless Chromium versus default Headless Shell, provide the explicit test and separate CLI configuration, and show browser-download commands that preserve both variants for full qualification. Explain that consumers can deliberately install only one variant for their own narrower workflow, but doing so does not exercise both qualified paths. Do not imply that Docker selects the mode or that these headless examples need Xvfb. Do not add an automated hook or make a browser download an npm lifecycle side effect merely to shorten the example.

Add suite mappings and qualification commands to the testing guide. State a bounded maintenance procedure: add another exact version only for a demonstrated need; review its upstream stable release, Ubuntu dependency groups, package changes, platform support and security notices; reuse an existing profile only if its reviewed requirements agree; otherwise approve a new profile and evaluate package conflicts. Add matching locked fixtures, execute the applicable qualification, and update the supported mapping, source references, README and examples together. Review and document any change to the release-fixed default or withdrawal of version support under collection versioning policy. Do not broaden support to neighbouring patches or ranges merely because the package names match.

Explain that consumers coordinate project upgrades with their image-build selector and rebuild when dependency requirements change. Explicit selection fixes the requested target but not the Ubuntu package binaries; changing a project lockfile alone is not a compatibility check. Do not claim that browser binaries or their downloads are locked by the npm lockfile.

**A9 — Documentation coherence:** public docs, source behaviour, default and supported-version mappings, browser-download choices, explicit headless configurations, examples, test assertions and qualified versions agree. All examples distinguish the Playwright target from a separately versioned CLI wrapper and regular Chromium from Headless Shell; no new capability is advertised as released before publication.

### P5 — Verify the implementation and obtain proportionate review (completed with accepted nested limitation)

Use the supported development environment. Run focused checks during implementation, then the complete relevant source-tree and candidate-artefact checks before declaring completion. Record exact commands, versions, resolved Ubuntu image identity, results and limitations under the established qualification process. Keep temporary logs and generated work under ignored `tmp/`.

The following are retained verification instructions for the implemented feature, not substitutes for exact-revision evidence when preparing a release. These focused suites were exercised during implementation; run them from the repository root:

```bash
./scripts/test-unit.sh foundation playwright-deps
./scripts/test-integration.sh playwright-deps
```

Run the configured shell and Markdown checks over the actual changed file sets. For the primary new shell files and installer documentation, the initial focused commands are:

```bash
shfmt -d -i 4 -ci installers/playwright-deps/install.sh tests/unit/playwright-deps/cli-test.sh
shellcheck --enable=all installers/playwright-deps/install.sh tests/unit/playwright-deps/cli-test.sh
markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/playwright-plan.md installers/playwright-deps/README.md
```

Add every other changed applicable file to those checks; do not limit lint to this example list. Run full source-tree qualification and candidate verification using the documented script interfaces:

```bash
./scripts/test.sh
revision="$(git rev-parse HEAD)"
./scripts/build-oci.sh ubuntu-devcontainer-installers:playwright-candidate 0.0.0 "${revision}"
./scripts/test-oci.sh ubuntu-devcontainer-installers:playwright-candidate 0.0.0 "${revision}"
git diff --check
```

A development candidate can contain uncommitted inputs; its revision label alone does not establish a clean release identity. Release qualification requires the approved source identity and gates in the release guide. If tooling is unavailable, first try the supported development environment and then report available checks and materially unverified behaviour. Missing credentials or source access are distinct from missing tooling.

Before finalising compatibility and security claims, assess independent review and reviewer capability separately. For a focused review of the dependency mapping, installer boundary, project examples and A1–A9 evidence, use the least costly capable reviewer with sufficient reasoning effort; do not automatically choose a stronger model for a mechanically verifiable change. If delegation is used, state the exact scope, selected model/effort and escalation trigger before dispatch. Escalate conflicting platform evidence, hidden privileges, new network sources or a proposed trust-boundary change to the responsible human rather than accepting a review as approval.

**Output and gate:** reviewed implementation and A1–A9 evidence, or a clear list of failures and unverified claims. Passing unit tests alone do not establish browser or packaged compatibility.

### P6 — Release and close the plan without changing unrelated consumers (pending approval)

Report changed files, reasons, commands/results, dependency and image-space impact, project-local browser-storage implications and any limitations. Do not migrate this repository's public/private development profiles, replace published digests or publish a release merely because implementation passes tests; those actions require their applicable approvals and qualification.

Use the existing single collection release unit and release workflow. A new installer is an additive capability; select the approved collection version through the established release policy rather than inventing a separate installer release mechanism. The root packaging Dockerfile already copies the complete `installers/` tree, so change it only if an actual packaging requirement is discovered.

Once the approved release is published and verified, update current availability and consumption references. Mark this plan completed with a concise delivery summary and links to the durable documentation owners. Preserve rationale and outstanding limitations without retaining stale instructions or duplicating the public contract.

## Primary references and revalidation inputs

These sources support the initial design and candidate baseline. They are not substitutes for P1 review or execution evidence. Recheck sources whose current contents or release metadata can change; retain exact accepted versions in durable implementation documentation.

- [Pinned Playwright 1.64.0 Ubuntu dependency definitions](https://github.com/microsoft/playwright/blob/606ecd8b34bac100db32561b6278ffd76e5eb3cd/packages/playwright-core/src/server/registry/nativeDeps.ts) and [1.64.1 definitions](https://github.com/microsoft/playwright/blob/cfe490d941f992655948eee8fd4fd94e1c4234bf/packages/playwright-core/src/server/registry/nativeDeps.ts): identical reviewed Ubuntu 26.04 tools + Chromium package mappings.
- [Pinned dependency installation and simulation behaviour](https://github.com/microsoft/playwright/blob/v1.64.0/packages/playwright-core/src/server/registry/dependencies.ts): explains why dry-run text is not a stable full dependency list.
- [Pinned browser registry and storage implementation](https://github.com/microsoft/playwright/blob/v1.64.0/packages/playwright-core/src/server/registry/index.ts): cache-path resolution, browser revisions, locking and unused-browser cleanup.
- [Pinned browser archive downloader](https://github.com/microsoft/playwright/blob/v1.64.0/packages/playwright-core/src/server/registry/oopDownloadBrowserMain.ts): supports the distinction between transfer checks and pinned archive-integrity verification.
- [Pinned browser-mode and installation guidance](https://github.com/microsoft/playwright/blob/v1.64.0/docs/src/browsers.md): candidate-release evidence for default Headless Shell, new headless mode through the `chromium` channel and the `--only-shell`/`--no-shell` download exclusions.
- [Official browser installation and storage guidance](https://playwright.dev/docs/browsers) and [system requirements](https://playwright.dev/docs/intro#system-requirements): current user guidance to verify against the chosen release.
- [Playwright Test 1.64.0 registry metadata](https://registry.npmjs.org/@playwright/test/1.64.0), [1.64.1 registry metadata](https://registry.npmjs.org/@playwright/test/1.64.1) and [separate CLI 0.1.22 registry metadata](https://registry.npmjs.org/@playwright/cli/0.1.22): exact package dependency evidence, not endorsement of the CLI's alpha dependencies.
- [Official separate CLI documentation](https://github.com/microsoft/playwright-cli): wrapper-specific behaviour and configuration to revalidate before claiming separately packaged CLI qualification.
- [Official Ubuntu package search](https://packages.ubuntu.com/): confirm selected package availability for the supported release and architecture, supplemented by fresh-image tests.
