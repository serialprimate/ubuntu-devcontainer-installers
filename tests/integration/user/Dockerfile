# syntax=docker/dockerfile:1
# check=error=true

# Replaces Ubuntu's default numeric identity and verifies secure default account state.
FROM ubuntu:26.04 AS default-account-replacement-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Confirms the base collision, replaces it and verifies identity, ownership and no sudo opt-in.
RUN test "$(getent passwd 1000 | cut -d: -f1)" = 'ubuntu' \
    && /workspace/installers/user/install.sh \
    && test ! "$(getent passwd ubuntu || true)" \
    && test "$(id -u dev)" = '1000' \
    && test "$(id -g dev)" = '1000' \
    && test "$(getent passwd dev | cut -d: -f7)" = '/bin/bash' \
    && test "$(stat -c '%u:%g' /home/dev)" = '1000:1000' \
    && test ! -e /home/ubuntu \
    && test ! -e /etc/sudoers.d/dev

# Replaces distinct name, UID, group-name and GID collisions after complete preflight.
FROM ubuntu:26.04 AS multiple-collision-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Creates independent removable collisions and verifies the requested identity replaces all of them.
RUN userdel --remove ubuntu \
    && groupadd --gid 2000 dev \
    && useradd --uid 2000 --gid 2000 --create-home --shell /bin/bash dev \
    && groupadd --gid 1000 legacy \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash legacy \
    && /workspace/installers/user/install.sh --username dev --uid 1000 --gid 1000 \
    && test "$(id -u dev)" = '1000' \
    && test "$(id -g dev)" = '1000' \
    && ! getent passwd legacy >/dev/null \
    && ! getent group legacy >/dev/null \
    && test ! -e /home/legacy

# Refuses a GID collision still used by an account outside the replacement set.
FROM ubuntu:26.04 AS collision-safety-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Verifies preflight failure leaves the otherwise removable UID-conflicting account intact.
RUN userdel --remove ubuntu \
    && groupadd --gid 1000 shared \
    && useradd --uid 2000 --gid 1000 --create-home --shell /bin/bash keeper \
    && groupadd --gid 3000 olddev \
    && useradd --uid 1000 --gid 3000 --create-home --shell /bin/bash olddev \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'cannot remove group shared: it is the primary group of keeper' \
        /workspace/installers/user/install.sh --username dev --uid 1000 --gid 1000 \
    && test "$(id -u olddev)" = '1000' \
    && test -d /home/olddev

# Rejects a missing supplementary group before replacing Ubuntu's default account.
FROM ubuntu:26.04 AS missing-group-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Proves prerequisite validation leaves the existing UID 1000 identity unchanged.
RUN /workspace/tests/lib/assert-command-fails.sh \
        1 'required supplementary group does not exist: absent-group' \
        /workspace/installers/user/install.sh --group absent-group \
    && test "$(getent passwd 1000 | cut -d: -f1)" = 'ubuntu'

# Repeats group and controlled-risk sudo requests and verifies warning and policy state.
FROM ubuntu:26.04 AS idempotent-sudo-success

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer used by this composition scenario.
COPY installers/user /workspace/installers/user

# Copies the APT installer used to establish the explicit sudo prerequisite.
COPY installers/apt-packages /workspace/installers/apt-packages

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Installs the explicit sudo prerequisite and creates one supplementary group.
RUN /workspace/installers/apt-packages/install.sh --package sudo \
    && groupadd docker

# Repeats the account request and verifies warning advice, memberships and validated file mode.
RUN output="$(/workspace/installers/user/install.sh \
        --group docker --allow-passwordless-sudo 2>&1)" \
    && [[ "${output}" == *'unrestricted root access without authentication'* ]] \
    && [[ "${output}" == *'prefer no sudo'* ]] \
    && output="$(/workspace/installers/user/install.sh \
        --group docker --allow-passwordless-sudo 2>&1)" \
    && [[ "${output}" == *'unrestricted root access without authentication'* ]] \
    && id --groups --name dev | tr ' ' '\n' | grep -Fxq docker \
    && test "$(stat -c '%a' /etc/sudoers.d/dev)" = '440' \
    && visudo -cf /etc/sudoers.d/dev

# Rejects execution by a non-root caller before account inspection.
FROM ubuntu:26.04 AS non-root-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

USER 65534:65534

# Verifies the explicit root requirement under an unprivileged build user.
RUN /workspace/tests/lib/assert-command-fails.sh \
    1 'user: error: must be run as root.' /workspace/installers/user/install.sh

# Rejects execution when release metadata does not identify Ubuntu 26.04.
FROM ubuntu:26.04 AS unsupported-platform-failure

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Copies the user installer.
COPY installers/user /workspace/installers/user

# Preserves the source-tree bundled-library relationship.
COPY lib /workspace/lib

# Copies the project-owned expected-failure assertion helper.
COPY tests/lib/assert-command-fails.sh /workspace/tests/lib/assert-command-fails.sh

# Substitutes unsupported metadata and proves platform validation occurs before account inspection.
RUN printf 'ID=ubuntu\nVERSION_ID="25.10"\n' >/etc/os-release \
    && /workspace/tests/lib/assert-command-fails.sh \
        1 'unsupported platform: requires Ubuntu 26.04' \
        /workspace/installers/user/install.sh
