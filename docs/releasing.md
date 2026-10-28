# Releasing

GitHub Actions is the only normal publication path. A developer must not manually push a routine release. This guide owns release approval, recovery and completion conditions; the [release workflow](../.github/workflows/release.yml) implements the automated path. [Conventions](../CONVENTIONS.md#oci-packaging) owns recurring packaging requirements and the [testing guide](testing.md#oci-candidate-verification) owns candidate-verification script interfaces.

## Repository configuration

The first publication established these required repository settings:

1. GitHub Actions can create and write the repository-associated GHCR package;
2. the protected `release` environment requires the project's chosen approvers;
3. the workflow permission policy permits the job-level `contents: write` and `packages: write` permissions; and
4. the `ubuntu-devcontainer-installers` package is publicly readable.

Administrators must preserve these settings. Release `0.1.0` completed the one-time GHCR visibility bootstrap; later releases verify anonymous digest-pinned access automatically. An installed client is not proof that its credentials, repository permissions or registry access are available.

## 0.6.0 release

The current collection version is `0.6.0`, an additive minor release under the [collection versioning policy](../README.md#versioning-and-release-qualification). The published image identity and qualification record are available in the [GitHub Release](https://github.com/serialprimate/ubuntu-devcontainer-installers/releases/tag/0.6.0). This release scope is not itself a qualification record.

The release scope since `0.5.1` is:

- Add `playwright-deps`, a dependency-only installer for project-owned Chromium and Chromium Headless Shell, supporting exact Playwright `1.64.0` and `1.64.1` targets with `1.64.1` the default. It installs neither npm packages nor browsers and adds no browser service or automatic runtime hook.
- Add bounded test concurrency through `TEST_JOBS`, coordinated output and per-test logs, with serial execution still the default. CI separates independent qualification gates; release qualification remains in one protected job.
- Run nested qualification as a non-root account matching the caller's UID/GID (1000 for a root caller), with read-only source mounts and an isolated writable workspace. Installer and service assertions continue inside disposable images.
- Standardise development/test logs under top-level `tmp/` without changing installer runtime temporary-file handling.

Before publication, complete the normal release procedure below against the reviewed clean tagged revision. The [Playwright implementation record](playwright-plan.md#status-and-outcome) retains earlier Ubuntu repository metadata download failures and the subsequent successful complete development run with `TEST_JOBS=4`. Development checks do not replace clean source, nested and packaged qualification of the approved release revision; no gate is waived.

After the workflow verifies publication, record the verified immutable `0.6.0` identity in the root README's OCI consumption guidance and confirm availability statements against the GitHub Release qualification record. Close the Playwright plan's publication gate only after its conditions are met. Keep historical release references intact. Development-profile digest migration additionally requires the [profile qualification procedure](testing.md#development-profile-qualification) and its approval; updating the collection version alone does not authorise it.

## Normal release

1. Confirm the default branch passes continuous integration and identify the reviewed commit to release.
2. Create an exact Semantic Versioning Git tag without a `v` prefix, such as `0.6.0`, at that commit. Do not move a published release tag.
3. Draft a GitHub Release for that tag and publish it after approval.
4. Approve the protected `release` environment deployment.
5. Confirm the workflow passes static/unit checks and complete source/nested qualification, builds once, passes packaged-artefact tests, publishes the exact, minor and major tags, and verifies an anonymous digest pull.
6. Confirm the [qualification record](#qualification-record) and immutable identity are attached to the GitHub Release before treating publication as complete.

Release verification and publication remain in one protected job so the approved revision, verified local candidate and complete qualification logs stay together. Like CI, the workflow uses `scripts/check.sh` for static/unit checks and the repository Actions variable `TEST_JOBS` for bounded execution, defaulting to 1. Increase that variable only after qualifying the intended runner; a successful higher-concurrency local run is not evidence that the same workload fits a smaller GitHub VM. The [testing guide](testing.md#scheduling-and-output) owns scheduling, output and infrastructure-abort behaviour.

The workflow uses only the repository-scoped `GITHUB_TOKEN`. Its tag set comes from `scripts/release-tags.sh`: release `0.6.0` publishes `0.6.0`, `0.6` and `0`, all for the same verified image. It never publishes `latest`.

If any gate fails, retain the logs and classify the failure before rerunning. Apply the publication-state conditions under [Failed publication recovery](#failed-publication-recovery) before rerunning the job. Partial tag publication or a successful authenticated push does not establish public availability or completion. Do not bypass an approval or failed verification to finish a release.

## Failed publication recovery

### Approval and inputs

Prefer rerunning the failed workflow job only after confirming that no exact-version publication exists and the approved convenience tags have not advanced to a later release. Inspect registry state even if a failed push did not return a digest; uncertain publication state is not proof that nothing was published. The current single-job workflow rebuilds with a new creation timestamp and pushes every tag on a rerun, so it cannot safely resume partial publication. Once the exact version exists, do not rerun that job: use the digest-reuse recovery path below.

Command-line publication is exceptional recovery only when verified publication cannot be safely resumed through GitHub Actions. An approver must explicitly authorise the recovery and confirm the exact release tag, reviewed full commit SHA, current publication state and intended tag set. Routine publication authority must not be inferred from possession of credentials.

Use the supported development environment, a clean checkout of the approved tag, a usable Docker/Buildx endpoint and retained qualification logs. Package publication requires a short-lived credential restricted to the required package access. Updating release notes and attachments separately requires authorised repository release-write access; do not broaden a package credential silently. Never put secret values in commands, logs, source files or image metadata.

Before building or pushing, inspect the failed workflow and existing release notes, attachments and registry tags. If an exact version is already published, establish its recorded digest and qualified revision first. Do not replace it with a rebuilt or different image. Reuse that verified digest-pinned candidate and rerun packaged verification; if identity cannot be established, stop for an approver's decision. If a convenience tag has advanced to a later approved release, do not move it backwards during recovery without explicit approval.

### Requalify the approved checkout and candidate

The following are consecutive Bash-session fragments run from the repository root, not an unattended publication script. Set `RELEASE_TAG` and `APPROVED_REVISION` to the approver-confirmed exact tag and full commit SHA before starting. Stop on any failed command or identity mismatch; do not substitute `HEAD` for an unknown approved revision.

Validate recovery identity and retain static/unit checks and complete source-tree qualification:

```bash
set -euo pipefail
: "${RELEASE_TAG:?Set the approved exact release tag}"
: "${APPROVED_REVISION:?Set the approved full commit SHA}"

# Validate approved source identity before building or publishing
release_tag_output="$(./scripts/release-tags.sh "${RELEASE_TAG}")"
mapfile -t release_tags <<<"${release_tag_output}"
revision="$(git rev-parse HEAD)"
test "${revision}" = "${APPROVED_REVISION}"
test "$(git rev-parse "refs/tags/${RELEASE_TAG}^{commit}")" = "${revision}"
test -z "$(git status --porcelain)"
image='ghcr.io/serialprimate/ubuntu-devcontainer-installers'
candidate="${image}:${RELEASE_TAG}"

# Retain independent source-tree qualification for this recovery
mkdir -p -- tmp
recovery_directory="$(mktemp -d tmp/release-recovery.XXXXXX)"
docker info >"${recovery_directory}/docker-info.log"
./scripts/check.sh |& tee "${recovery_directory}/checks.log"
./scripts/test.sh |& tee "${recovery_directory}/source-tests.log"
```

If the exact version is already published, set `PUBLISHED_DIGEST` to its established qualified digest. Otherwise, leave that variable unset only after confirming that no exact-version publication exists. The following fragment selects the approved branch and uses the canonical [candidate script interface](testing.md#oci-candidate-verification).

Reuse the established image or build the unpublished candidate once, then verify it before any push:

```bash
# Reuse an existing published identity rather than rebuilding it
if [[ -n "${PUBLISHED_DIGEST:-}" ]]; then
    [[ "${PUBLISHED_DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]]
    docker pull --platform linux/amd64 "${image}@${PUBLISHED_DIGEST}"
    docker image tag "${image}@${PUBLISHED_DIGEST}" "${candidate}"
else
    ./scripts/build-oci.sh "${candidate}" "${RELEASE_TAG}" "${revision}"
fi

# Verify the same candidate that will be published
./scripts/test-oci.sh "${candidate}" "${RELEASE_TAG}" "${revision}" \
    |& tee "${recovery_directory}/packaged-tests.log"
```

Preserve the candidate's local image ID, qualification logs and Ubuntu image digest before changing local tags. Candidate verification checks platform, source/version/revision labels and the non-runtime image configuration as well as packaged behaviour; source tests alone are insufficient.

### Publish only the verified image

Authenticate through standard input as in the [release workflow](../.github/workflows/release.yml), using the approved short-lived credential. Apply only `release_tags` returned above, with `docker image tag "${candidate}" "${image}:${tag}"`, and push those references with `docker push "${image}:${tag}"`, retaining each push result under `recovery_directory`. The exact candidate is already tagged; do not rebuild between verification and publication. Never publish `latest`, invent an extra tag or alter a convenience tag independently of the approved set.

Record the digest returned by the exact-version push and validate its full `sha256:` plus 64 lowercase hexadecimal form. Every tag's push result must identify that same digest. For an already-published candidate, it must also equal `PUBLISHED_DIGEST`. If any push fails or a digest differs, stop, retain partial-publication evidence and re-establish identity before attempting another operation; do not assume a loop completed all tags.

### Verify public consumption and finish

Log out of GHCR and remove the local release-tag references, as the workflow does, so an authenticated session or local tag cannot stand in for anonymous registry access. Set `DIGEST` to the validated published digest, then run the public-consumption check:

```bash
docker pull --platform linux/amd64 "${image}@${DIGEST}"
```

A failed anonymous pull is an incomplete publication, not a passing release with a documentation caveat. Resolve access or publication failure before proceeding. Using authorised release-write access, attach the qualification report and update the existing release's OCI identity section without discarding its other notes. Retain recovery evidence until the approver confirms the identity and record are complete; then remove no-longer-needed local logs and candidates using the repository's resource-ownership conventions.

## Qualification record

The workflow and approved recovery must leave equivalent durable evidence in the existing GitHub Release:

- `qualification-<version>.md`, containing the full source revision, immutable OCI reference, exact/minor/major tag set, resolved Ubuntu qualification image digest, `linux/amd64` target, Docker and builder version information, the selected worker bound (`TEST_JOBS`, or 1 when unset), and complete static/unit, source-tree and packaged-artefact command results.
- An `OCI release identity` section containing the same immutable image digest and source revision, plus a link to that attached report.
- Successful anonymous digest-pinned consumption, with any recovery approval and exceptional actions recorded without credentials or secret values.

The [release workflow's record-generation step](../.github/workflows/release.yml) defines the automated report format; recovery must retain the same evidence rather than merely declare that tests passed. Publication is complete only when every required verification passes, the approved tags identify the verified image, anonymous access succeeds, the durable record is accurate and all required approvals are satisfied. Tests and reports support approval; they do not replace it.
