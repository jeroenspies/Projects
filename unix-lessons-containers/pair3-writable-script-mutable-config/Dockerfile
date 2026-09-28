# Keep the digest in sync with DEBIAN_IMAGE in ../scripts/lib.sh.
FROM debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        passwd \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 1000 --home-dir /home/appuser --create-home --shell /bin/sh appuser

COPY run-inside.sh /usr/local/bin/run-inside.sh
RUN chmod 0755 /usr/local/bin/run-inside.sh
