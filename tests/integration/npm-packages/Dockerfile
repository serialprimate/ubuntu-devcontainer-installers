# syntax=docker/dockerfile:1
# check=error=true

# Installs multiple global package sets from the packaged collection layout after Node.js.
FROM ubuntu:26.04 AS multiple-package-sets-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the prerequisite package installer beneath the stable collection payload root.
COPY installers/apt-packages /opt/ubuntu-devcontainer-installers/installers/apt-packages

# Copies the Node.js installer beside its explicit prerequisite installer.
COPY installers/node /opt/ubuntu-devcontainer-installers/installers/node

# Copies the npm package installer beside its Node.js prerequisite.
COPY installers/npm-packages /opt/ubuntu-devcontainer-installers/installers/npm-packages

# Preserves the bundled-library relationship used by both installers.
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Composes prerequisites, then exercises repeatable values, age controls and independent sets.
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates \
        --package curl \
        --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh --node-version 24 \
    && /opt/ubuntu-devcontainer-installers/installers/npm-packages/install.sh \
        --package is-number@7.0.0 \
        --package is-odd@3.0.1 \
    && /opt/ubuntu-devcontainer-installers/installers/npm-packages/install.sh \
        --package ansi-regex@5.0.1 \
        --minimum-release-age-days 30 \
    && npm list --global --depth=0 is-number@7.0.0 is-odd@3.0.1 ansi-regex@5.0.1

# Verifies explicit delay disablement and secure package-script arguments with a recording npm.
FROM ubuntu:26.04 AS release-age-disable-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the npm package installer.
COPY installers/npm-packages /workspace/installers/npm-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs a deterministic recording npm command for argument inspection.
RUN printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "${1:-}" == "--version" ]]; then printf "11.10.0\\n"; exit; fi' \
        'printf "%s\\n" "$@" >/tmp/npm-arguments' \
        >/usr/local/bin/npm \
    && chmod 0755 /usr/local/bin/npm

# Proves explicit disablement omits only the release-age argument and preserves literal packages.
RUN /workspace/installers/npm-packages/install.sh \
        --package @scope/tool@stable \
        --without-minimum-release-age \
    && grep -Fxq -- '--global' /tmp/npm-arguments \
    && grep -Fxq -- '--ignore-scripts' /tmp/npm-arguments \
    && grep -Fxq -- '@scope/tool@stable' /tmp/npm-arguments \
    && ! grep -Fq -- '--min-release-age=' /tmp/npm-arguments

# Reports the required installer composition order when npm is absent.
FROM ubuntu:26.04 AS prerequisite-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the npm package installer and expected-failure helper.
COPY installers/npm-packages /workspace/installers/npm-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Verifies the missing prerequisite identifies Node.js-first composition.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'Run installers/node/install.sh before invoking npm-packages' \
    /workspace/installers/npm-packages/install.sh --package is-number@7.0.0

# Rejects npm versions that cannot enforce the default release-age control.
FROM ubuntu:26.04 AS unsupported-npm-version-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the npm package installer and expected-failure helper.
COPY installers/npm-packages /workspace/installers/npm-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Provides an old npm version without implementing an installation operation.
RUN printf '%s\n' '#!/usr/bin/env bash' 'printf "11.9.0\\n"' >/usr/local/bin/npm \
    && chmod 0755 /usr/local/bin/npm

# Proves the requested default control fails clearly rather than being silently omitted.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'minimum release age requires npm 11.10.0 or newer; found 11.9.0' \
    /workspace/installers/npm-packages/install.sh --package is-number@7.0.0

# Rejects unsupported release metadata before invoking an available npm command.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the npm package installer and expected-failure helper.
COPY installers/npm-packages /workspace/installers/npm-packages

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Substitutes unsupported metadata and proves platform validation precedes npm execution.
RUN printf 'ID=debian\nVERSION_ID="13"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/npm-packages/install.sh --package is-number@7.0.0
