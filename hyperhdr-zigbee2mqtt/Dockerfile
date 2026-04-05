ARG BUILD_FROM
FROM $BUILD_FROM AS base

ENV LANG C.UTF-8

# Build stage: clone awawa-dev fork and install dependencies
FROM base AS builder

RUN apk add --no-cache --virtual .buildtools \
    nodejs npm make gcc g++ linux-headers udev git python3 curl && \
    git clone -b master --single-branch --depth 1 \
        https://github.com/awawa-dev/zigbee2mqtt.git /app && \
    cd /app && \
    # Install pnpm (fork uses same toolchain as upstream z2m 1.42.x)
    npm install -g pnpm && \
    # Use --no-frozen-lockfile because the herdsman dep is a git URL
    # which may not match the committed lockfile exactly
    pnpm install --no-frozen-lockfile --no-optional --unsafe-perm && \
    pnpm run build && \
    rm -rf node_modules && \
    pnpm install --no-frozen-lockfile --no-optional --unsafe-perm --prod && \
    # Rebuild serialport native bindings for current platform
    rm -rf $(find ./node_modules/.pnpm/ -wholename "*/@serialport/bindings-cpp/prebuilds" -type d) && \
    pnpm rebuild @serialport/bindings-cpp && \
    apk del .buildtools

# Runtime stage
FROM base AS release

RUN apk add --no-cache nodejs eudev curl

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json /app/index.js ./

COPY rootfs/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENV NODE_ENV production

HEALTHCHECK --interval=1m --timeout=3s --start-period=30s --start-interval=3s \
    CMD curl -f http://localhost:8099/

ENTRYPOINT ["/docker-entrypoint.sh"]
