# Releasing

GitHub Actions is the only normal publication path. A developer must not manually push a routine release.

## Repository configuration

The first publication established these required repository settings:

1. GitHub Actions can create and write the repository-associated GHCR package;
2. the protected `release` environment requires the project’s chosen approvers;
3. the workflow permission policy permits the job-level `contents: write` and `packages: write` permissions; and
4. the `ubuntu-devcontainer-installers` package is publicly readable.

Administrators must preserve these settings. Release `0.1.0` completed the one-time GHCR visibility bootstrap; every later release verifies anonymous digest-pinned access automatically.

## Normal release

1. Confirm the default branch passes continuous integration.
2. Create an exact Semantic Versioning Git tag without a `v` prefix, such as `0.2.0`, at the reviewed commit.
3. Draft a GitHub Release for that tag and publish it after approval.
4. Approve the protected `release` environment deployment.
5. Confirm the workflow passes source-tree tests, builds once, passes packaged-artefact tests, publishes the exact, minor and major tags, and verifies an anonymous digest pull.
6. Confirm the workflow attached `qualification-<version>.md` and added the immutable digest and source revision to the GitHub Release notes.

The workflow uses only the repository-scoped `GITHUB_TOKEN`. It publishes `0.2.0`, `0.2` and `0` for release `0.2.0`; it never publishes `latest`.

## Failed publication recovery

Prefer rerunning the failed workflow job. A command-line push is an exceptional recovery procedure only when GitHub Actions cannot resume after verification succeeded. Before a recovery push, an approver must confirm that the local checkout is the exact release tag and revision, rerun `./scripts/test.sh`, build the candidate with `./scripts/build-oci.sh`, and run `./scripts/test-oci.sh` against that candidate. Authenticate with a short-lived credential having no broader access than package publication, apply only the tags emitted by `./scripts/release-tags.sh`, and push the same verified local image without rebuilding it.

After recovery, record the pushed digest, source revision and complete qualification information in the existing GitHub Release exactly as the workflow does. Do not create `latest`, alter a convenience tag independently, omit required OCI labels or treat recovery as an alternative routine release process.
