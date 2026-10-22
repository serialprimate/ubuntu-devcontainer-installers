# syntax=docker/dockerfile:1
# check=error=true

# Preserves the source layout in a clean Ubuntu image with no JavaScript toolchain
FROM ubuntu:26.04 AS installer-base

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the dependency installer and its bundled libraries
COPY installers/playwright-deps /workspace/installers/playwright-deps

# Preserves installer-relative shared-library resolution
COPY lib /workspace/lib

# Copies independent package assertions and expected-failure helpers
COPY tests/integration/playwright-deps/assert-dependencies.sh tests/integration/playwright-deps/expected-packages.txt /checks/

# Copies the repository's literal expected-failure assertion helper
COPY tests/lib/assert-command-fails.sh /checks/assert-command-fails.sh

# Verifies the release-fixed default without any Node.js prerequisite
FROM installer-base AS default-success

# Installs the default profile and checks its complete dependency-only outcome
RUN /workspace/installers/playwright-deps/install.sh \
    && /checks/assert-dependencies.sh

# Verifies explicit supported selection independently of the default scenario
FROM installer-base AS explicit-success

# Installs the exact approved target and checks the reviewed package state
RUN /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.0 \
    && /checks/assert-dependencies.sh

# Verifies independent APT lifecycles on repeated default and explicit requests
FROM installer-base AS repeated-success

# Repeats both equivalent selections without removing existing unrelated packages
RUN /workspace/installers/playwright-deps/install.sh \
    && /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.0 \
    && /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.1 \
    && /checks/assert-dependencies.sh

# Rejects unsupported targets without changing package or repository state
FROM installer-base AS unsupported-version-failure

# Confirms that a nearby version is not inferred to be supported
RUN before="$(sha256sum /var/lib/dpkg/status /etc/apt/sources.list.d/ubuntu.sources)" \
    && /checks/assert-command-fails.sh 1 'supported versions: 1.64.0, 1.64.1' \
        /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.2 \
    && test "${before}" = "$(sha256sum /var/lib/dpkg/status /etc/apt/sources.list.d/ubuntu.sources)" \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Rejects unsupported Ubuntu release metadata before APT operations
FROM installer-base AS unsupported-platform-failure

# Substitutes an unsupported release and checks the platform diagnostic
RUN printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >/etc/os-release \
    && /checks/assert-command-fails.sh 1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/playwright-deps/install.sh

# Rejects unsupported architecture without requiring a foreign machine
FROM installer-base AS unsupported-architecture-failure

# Overrides architecture reporting within this disposable scenario
RUN printf '#!/bin/bash\nprintf "aarch64\\n"\n' >/usr/local/bin/uname \
    && chmod 0755 /usr/local/bin/uname \
    && /checks/assert-command-fails.sh 1 'unsupported architecture: requires linux/amd64' \
        /workspace/installers/playwright-deps/install.sh

# Verifies missing intrinsic prerequisites fail clearly before installation
FROM installer-base AS prerequisite-failure

# Removes only this disposable image's APT executable to test the prerequisite diagnostic
RUN mv /usr/bin/apt-get /usr/bin/apt-get.disabled \
    && /checks/assert-command-fails.sh 1 'required command not found: apt-get' \
        /workspace/installers/playwright-deps/install.sh

# Verifies errors from the owned APT lifecycle remain actionable
FROM installer-base AS apt-failure

# Uses a failing package manager without weakening repository or TLS verification
RUN printf '#!/bin/bash\nexit 42\n' >/usr/local/bin/apt-get \
    && chmod 0755 /usr/local/bin/apt-get \
    && /checks/assert-command-fails.sh 1 'APT metadata refresh failed' \
        /workspace/installers/playwright-deps/install.sh

# Verifies root requirements without granting the test user any elevation
FROM installer-base AS non-root-failure

USER 65534:65534

# Allows help while rejecting a supported installation request from an unprivileged caller
RUN /workspace/installers/playwright-deps/install.sh --help \
    && /checks/assert-command-fails.sh 1 'must be run as root' \
        /workspace/installers/playwright-deps/install.sh

# Composes the complete development environment only for project-local qualification
FROM installer-base AS browser-base

# Copies explicit prerequisite installers without changing their contracts
COPY installers/apt-packages /workspace/installers/apt-packages

# Copies the independently composed Node.js installer
COPY installers/node /workspace/installers/node

# Copies the independently composed development-user installer
COPY installers/user /workspace/installers/user

# Installs root-owned image components before switching permanently to the development user
RUN /workspace/installers/apt-packages/install.sh --package ca-certificates --package curl --package gnupg \
    && /workspace/installers/node/install.sh --node-version 24 \
    && /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.1 \
    && /workspace/installers/user/install.sh

# Copies the minimal locked test project with user-owned, writable project storage
COPY --chown=1000:1000 tests/integration/playwright-deps/project /home/dev/project

USER dev
ENV HOME=/home/dev XDG_CACHE_HOME=/home/dev/project/.cache CI=1 NO_UPDATE_NOTIFIER=1 \
    PLAYWRIGHT_TEST_TARGET=1.64.1
WORKDIR /home/dev/project

# Installs only locked local packages without lifecycle scripts or a global Playwright command
RUN test "$(id -u)" != 0 \
    && npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7

# Preserves independently locked packages for the retained supported version
FROM browser-base AS browser-1-64-0-base

USER root

# Exercises cross-version profile reuse before qualifying the retained project package version
RUN /workspace/installers/playwright-deps/install.sh --playwright-version 1.64.0

# Replaces only manifests while sharing all browser tests, helpers and configuration
COPY --chown=1000:1000 tests/integration/playwright-deps/project-1-64-0/ /home/dev/project/

USER dev
ENV PLAYWRIGHT_TEST_TARGET=1.64.0

# Installs the retained version from its original lockfile without weakening the release-age policy
RUN npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7

# Retains a project-owned browser directory across npm dependency reinstalls
FROM browser-base AS separate-storage-success

# Downloads both Chromium variants as the development user into the separate project directory
RUN node project-playwright.cjs separate install chromium

# Runs real browser interactions and a CLI session with external networking disabled
RUN --network=none node verify-project.cjs separate

# Reinstalls project packages without deleting the separate browser store
RUN npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7 \
    && test -d ms-playwright

# Proves the retained browsers still work without any download or display server
RUN --network=none node verify-project.cjs separate

# Keeps browsers beneath the local Playwright package instead of a separate directory
FROM browser-base AS package-storage-success

# Downloads both variants using the supported package-local storage setting
RUN node project-playwright.cjs package install chromium

# Exercises both headless executables and the independently configured CLI without network access
RUN --network=none node verify-project.cjs package

# Demonstrates that npm ci removes browsers together with the previous node_modules tree
RUN npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7

# Checks that tests fail actionably rather than silently downloading missing browsers
RUN --network=none node verify-project.cjs package missing

# Restores browsers only through the explicitly documented installation step
RUN node project-playwright.cjs package install chromium

# Requalifies the restored project-local browsers and CLI without external networking
RUN --network=none node verify-project.cjs package

# Qualifies the retained version with separate project-local browser storage
FROM browser-1-64-0-base AS separate-storage-1-64-0-success

# Downloads the retained target's matching browsers without sharing a prior fixture cache
RUN node project-playwright.cjs separate install chromium

# Exercises both headless executables, JavaScript, TypeScript and CLI on the retained version
RUN --network=none node verify-project.cjs separate

# Keeps the separate browser store while reinstalling the retained locked npm dependencies
RUN npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7 \
    && test -d ms-playwright

# Verifies reuse after npm ci without allowing implicit browser downloads
RUN --network=none node verify-project.cjs separate

# Qualifies the retained version with browsers beneath its own local package tree
FROM browser-1-64-0-base AS package-storage-1-64-0-success

# Downloads both variants for the retained version into its resolved Playwright package
RUN node project-playwright.cjs package install chromium

# Exercises the retained version's package-local browser and CLI paths without networking
RUN --network=none node verify-project.cjs package

# Removes the retained version's package-local browsers through a real dependency reinstall
RUN npm ci --ignore-scripts --no-audit --no-fund --min-release-age=7

# Proves that removing package-local browsers requires an explicit reinstall
RUN --network=none node verify-project.cjs package missing

# Restores only the retained target's Chromium browsers through the normal explicit command
RUN node project-playwright.cjs package install chromium

# Verifies restored functionality for the retained supported version
RUN --network=none node verify-project.cjs package
