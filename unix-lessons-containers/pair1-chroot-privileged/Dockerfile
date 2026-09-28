# Keep the digest in sync with DEBIAN_IMAGE in ../scripts/lib.sh.
FROM debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

# capsh decodes CapEff. bind80 has no file capability.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        libcap2-bin \
        passwd \
    && rm -rf /var/lib/apt/lists/*

COPY src/bind80.c src/try-chroot.c /tmp/src/
COPY observe.sh /usr/local/bin/observe.sh

RUN gcc -Wall -Wextra -Werror -O2 -o /usr/local/bin/bind80 /tmp/src/bind80.c \
    && gcc -Wall -Wextra -Werror -O2 -o /usr/local/bin/try-chroot /tmp/src/try-chroot.c \
    && chmod 0755 /usr/local/bin/observe.sh /usr/local/bin/bind80 \
        /usr/local/bin/try-chroot \
    && useradd --uid 1000 --home-dir /home/appuser --create-home --shell /bin/sh appuser \
    && rm -rf /tmp/src
