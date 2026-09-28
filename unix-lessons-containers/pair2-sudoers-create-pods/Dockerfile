# Keep the digest in sync with DEBIAN_IMAGE in ../scripts/lib.sh.
FROM debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        less \
        passwd \
        sudo \
    && rm -rf /var/lib/apt/lists/*

COPY src/try-exec.c /tmp/try-exec.c
COPY editor-id.sh /usr/local/bin/editor-id
COPY sudoers /etc/sudoers.d/demo
COPY run-inside.sh /usr/local/bin/run-inside.sh

RUN gcc -Wall -Wextra -Werror -O2 -o /usr/local/bin/try-exec /tmp/try-exec.c \
    && cp -a /usr/local/bin/try-exec /usr/local/bin/try-exec-noexec \
    && chmod 0755 /usr/local/bin/try-exec /usr/local/bin/try-exec-noexec \
        /usr/local/bin/editor-id /usr/local/bin/run-inside.sh \
    && chmod 0440 /etc/sudoers.d/demo \
    && visudo -cf /etc/sudoers.d/demo \
    && useradd --uid 1000 --home-dir /home/testuser --create-home --shell /bin/sh testuser \
    && rm -f /tmp/try-exec.c
