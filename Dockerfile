# Immagine MinIO (server + client mc) compilata dal sorgente upstream.
#
# MinIO community non e' piu' distribuito in forma binaria: le immagini su Docker Hub
# sono ritirate, quelle su Quay rispondono 401 e dl.min.io risponde 410. I repository
# GitHub sono archiviati ma il sorgente AGPL e i tag restano leggibili: qui si compila
# una release pinnata per commit.
#
# Il layout replica l'immagine upstream (Dockerfile.release): stessa base, stesso
# entrypoint, binari in /usr/bin, licenze in /licenses. Si usa come server
# (`command: server /data`) o come client (`--entrypoint /bin/sh ... mc ...`).
#
# Build multi-arch senza emulazione: il compilatore gira sull'architettura del runner
# e produce il binario per TARGETARCH (CGO disabilitato, come upstream).

ARG MINIO_RELEASE=RELEASE.2025-09-07T16-13-09Z
ARG MINIO_COMMIT=07c3a429bfed433e49018cb0f78a52145d4bedeb
ARG MC_RELEASE=RELEASE.2025-08-13T08-35-41Z
ARG MC_COMMIT=7394ce0dd2a80935aded936b09fa12cbb3cb8096

FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build

ARG TARGETOS=linux
ARG TARGETARCH
ARG MINIO_RELEASE
ARG MINIO_COMMIT
ARG MC_RELEASE
ARG MC_COMMIT

ENV CGO_ENABLED=0

RUN apk add --no-cache git ca-certificates

# Checkout per commit, non per tag: un tag si puo' spostare, un commit no. Il
# confronto con HEAD rende esplicito un repository che non contiene piu' il commit.
# $1 repository, $2 commit, $3 directory.
RUN printf '%s\n' \
      'set -eu' \
      'git init -q "$3"' \
      'git -C "$3" fetch -q --depth 1 "$1" "$2"' \
      'git -C "$3" checkout -q FETCH_HEAD' \
      'test "$(git -C "$3" rev-parse HEAD)" = "$2"' \
      > /usr/local/bin/checkout-commit && chmod +x /usr/local/bin/checkout-commit

# Il RELEASE.<data> diventa la data RFC3339 che gen-ldflags.go si aspetta: e' cosi' che
# `minio --version` e `mc --version` riportano la release e non "DEVELOPMENT".
RUN checkout-commit https://github.com/minio/minio.git "$MINIO_COMMIT" /src/minio && \
    cd /src/minio && \
    ts=$(echo "$MINIO_RELEASE" | sed -E 's/^RELEASE\.([0-9-]+)T([0-9]+)-([0-9]+)-([0-9]+)Z$/\1T\2:\3:\4Z/') && \
    ldflags=$(MINIO_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "$ts") && \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -tags kqueue -trimpath -ldflags "$ldflags" -o /out/minio

RUN checkout-commit https://github.com/minio/mc.git "$MC_COMMIT" /src/mc && \
    cd /src/mc && \
    ts=$(echo "$MC_RELEASE" | sed -E 's/^RELEASE\.([0-9-]+)T([0-9]+)-([0-9]+)-([0-9]+)Z$/\1T\2:\3:\4Z/') && \
    ldflags=$(MC_RELEASE=RELEASE go run buildscripts/gen-ldflags.go "$ts") && \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go build -tags kqueue -trimpath -ldflags "$ldflags" -o /out/mc

FROM registry.access.redhat.com/ubi9/ubi-micro:9.6

ARG MINIO_RELEASE
ARG MC_RELEASE

LABEL org.opencontainers.image.title="minio" \
      org.opencontainers.image.version="${MINIO_RELEASE}" \
      org.opencontainers.image.source="https://github.com/jarvit/minio-image" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.description="MinIO server ${MINIO_RELEASE} + mc ${MC_RELEASE}, compilati dal sorgente upstream"

ENV MINIO_ACCESS_KEY_FILE=access_key \
    MINIO_SECRET_KEY_FILE=secret_key \
    MINIO_ROOT_USER_FILE=access_key \
    MINIO_ROOT_PASSWORD_FILE=secret_key \
    MINIO_KMS_SECRET_KEY_FILE=kms_master_key \
    MINIO_CONFIG_ENV_FILE=config.env \
    MC_CONFIG_DIR=/tmp/.mc

COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/minio /out/mc /usr/bin/
COPY --from=build /src/minio/LICENSE /src/minio/CREDITS /licenses/
COPY --from=build /src/minio/dockerscripts/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh

EXPOSE 9000
VOLUME ["/data"]

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["minio"]
