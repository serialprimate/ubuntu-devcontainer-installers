# syntax=docker/dockerfile:1
# check=error=true

# Installs and repeats the default Ubuntu Python toolset in a fresh image.
FROM ubuntu:26.04 AS default-idempotent-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the apt-python installer.
COPY installers/apt-python /workspace/installers/apt-python

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Repeats installation and verifies the interpreter, pip, venv and APT cleanup outcomes.
RUN /workspace/installers/apt-python/install.sh \
    && /workspace/installers/apt-python/install.sh \
    && python3 --version \
    && python3 -m pip --version \
    && python3 -m venv /tmp/apt-python-venv \
    && rm -rf -- /tmp/apt-python-venv \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Installs only the required Python runtime when both optional tools are omitted.
FROM ubuntu:26.04 AS runtime-only-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the apt-python installer.
COPY installers/apt-python /workspace/installers/apt-python

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Verifies the explicit minimal package selection and successful APT cleanup.
RUN /workspace/installers/apt-python/install.sh --without-pip --without-venv \
    && python3 --version \
    && test "$(dpkg-query --show --showformat='${db:Status-Abbrev}' \
        python3-pip 2>/dev/null || true)" != 'ii' \
    && test "$(dpkg-query --show --showformat='${db:Status-Abbrev}' \
        python3-venv 2>/dev/null || true)" != 'ii' \
    && test -z "$(ls -A /var/lib/apt/lists)"

# Rejects duplicate scalar options without touching APT state.
FROM ubuntu:26.04 AS invalid-input-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the apt-python installer.
COPY installers/apt-python /workspace/installers/apt-python

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Verifies that duplicate scalar options return a qualified failure.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'option may be specified only once: --without-pip' \
    /workspace/installers/apt-python/install.sh --without-pip --without-pip

# Rejects execution when release metadata does not identify Ubuntu 26.04.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the apt-python installer.
COPY installers/apt-python /workspace/installers/apt-python

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Substitutes unsupported metadata and proves platform validation precedes APT operations.
RUN printf 'ID=debian\nVERSION_ID="13"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/apt-python/install.sh
