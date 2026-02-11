# syntax=docker/dockerfile:1.7

ARG GO_VERSION=1.24.11
ARG NODE_VERSION=24.11.0

############################
# Stage 1: Build web client
############################
FROM node:${NODE_VERSION}-bookworm-slim AS webapp-builder
WORKDIR /src/webapp

# Copy workspace manifests first to maximize dependency-layer cache reuse.
COPY webapp/package*.json ./
COPY webapp/channels/package*.json ./channels/
COPY webapp/platform/types/package*.json ./platform/types/
COPY webapp/platform/client/package*.json ./platform/client/
COPY webapp/platform/components/package*.json ./platform/components/
COPY webapp/platform/eslint-plugin/package*.json ./platform/eslint-plugin/
COPY webapp/platform/mattermost-redux/package*.json ./platform/mattermost-redux/

# Install dependencies only at this stage. We intentionally skip scripts because
# webapp postinstall builds workspace packages and requires full source files.
RUN --mount=type=cache,target=/root/.npm npm ci --include=dev --ignore-scripts

# Copy full source, then run postinstall and final production build.
COPY webapp/ ./
RUN --mount=type=cache,target=/root/.npm npm run postinstall && npm run build

############################
# Stage 2: Build server binaries from source
############################
FROM golang:${GO_VERSION}-bookworm AS server-builder
WORKDIR /src/server

ARG BUILD_NUMBER=dev
ARG BUILD_DATE
ARG BUILD_HASH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates make git \
    && rm -rf /var/lib/apt/lists/*

# Prime go module cache first
COPY server/go.mod server/go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Copy server sources and compile
COPY server/ ./

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    # Align with the upstream build flow by using local workspace modules. \
    rm -f go.work go.work.sum; \
    go work init . ./public; \
    : "${BUILD_DATE:=$(date -u +'%Y-%m-%dT%H:%M:%SZ')}"; \
    : "${BUILD_HASH:=$(git rev-parse HEAD 2>/dev/null || echo unknown)}"; \
    LDFLAGS="-s -w \
      -X github.com/mattermost/mattermost/server/public/model.BuildNumber=${BUILD_NUMBER} \
      -X github.com/mattermost/mattermost/server/public/model.BuildDate=${BUILD_DATE} \
      -X github.com/mattermost/mattermost/server/public/model.BuildHash=${BUILD_HASH} \
      -X github.com/mattermost/mattermost/server/public/model.BuildHashEnterprise=none \
      -X github.com/mattermost/mattermost/server/public/model.BuildEnterpriseReady=false"; \
    CGO_ENABLED=1 GOOS=linux GOARCH=$(go env GOARCH) go build -trimpath -tags 'production sourceavailable' -ldflags "${LDFLAGS}" -o /out/mattermost ./cmd/mattermost; \
    CGO_ENABLED=1 GOOS=linux GOARCH=$(go env GOARCH) go build -trimpath -tags 'production sourceavailable' -ldflags "${LDFLAGS}" -o /out/mmctl ./cmd/mmctl

# Assemble a runtime filesystem layout similar to official packaging
RUN set -eux; \
    mkdir -p /out/layout/{bin,client,config,fonts,i18n,logs,plugins,data,templates}; \
    OUTPUT_CONFIG=/out/layout/config/config.json go run ./scripts/config_generator; \
    cp -a fonts/. /out/layout/fonts/; \
    cp -a i18n/. /out/layout/i18n/; \
    cp -a templates/. /out/layout/templates/; \
    cp -a /out/mattermost /out/layout/bin/mattermost; \
    cp -a /out/mmctl /out/layout/bin/mmctl

COPY --from=webapp-builder /src/webapp/channels/dist/ /out/layout/client/

############################
# Stage 3: Production runtime
############################
FROM debian:bookworm-slim

ARG PUID=2000
ARG PGID=2000

ENV PATH="/mattermost/bin:${PATH}" \
    MM_SERVICESETTINGS_ENABLELOCALMODE=true \
    MM_INSTALL_TYPE=docker

# Runtime dependencies for file preview/conversion and TLS
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      tzdata \
      unrtf \
      wv \
      poppler-utils \
      tidy \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${PGID}" mattermost \
    && useradd --uid "${PUID}" --gid "${PGID}" --home-dir /mattermost --create-home --shell /usr/sbin/nologin mattermost

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --from=server-builder /out/layout /mattermost

RUN mkdir -p /mattermost/.postgresql /mattermost/client/plugins \
    && chmod 700 /mattermost/.postgresql \
    && chown -R mattermost:mattermost /mattermost \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /mattermost
USER mattermost

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD ["/mattermost/bin/mmctl", "system", "status", "--local"]

EXPOSE 8065 8067 8074 8075
VOLUME ["/mattermost/data", "/mattermost/logs", "/mattermost/config", "/mattermost/plugins", "/mattermost/client/plugins"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["mattermost"]
