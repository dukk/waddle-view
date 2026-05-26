# syntax=docker/dockerfile:1
# nginx :443 (self-signed) → static SPA + proxy /bff → Node BFF :5199 (HTTP loopback).
# Build from repository root: docker build -f apps/waddle_controller/Dockerfile .

# glibc builder: native addons ship linux-x64 prebuilds (Alpine musl often misses them).
FROM node:22-bookworm-slim AS build
# Official node images default NODE_ENV=production, which omits devDependencies (tsc, vite).
ENV NODE_ENV=development
ARG WADDLE_CONTROLLER_BUILD_NUMBER=dev
ENV WADDLE_CONTROLLER_BUILD_NUMBER=$WADDLE_CONTROLLER_BUILD_NUMBER
ENV WADDLE_NODE_TLS_ROOT=/packages/waddle_node_tls
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    python3 make g++ libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY packages/waddle_node_tls /packages/waddle_node_tls
RUN npm ci --prefix /packages/waddle_node_tls
# Install deps before copying the rest of the tree (layer cache + postinstall needs tool/*.mjs).
COPY apps/waddle_controller/package.json apps/waddle_controller/package-lock.json ./
RUN test -s package-lock.json
RUN npm ci --ignore-scripts
COPY apps/waddle_controller/ .
COPY LICENSE /waddle-repo/LICENSE
ENV WADDLE_VIEW_REPO_ROOT=/waddle-repo
RUN npm run postinstall \
  && npm run build \
  && npm run build:server \
  && npm prune --omit=dev

FROM node:22-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends nginx openssl wget ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=build /app/server/dist ./server/dist
COPY apps/waddle_controller/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY apps/waddle_controller/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENV NODE_ENV=production
ENV PORT=5199
ENV WADDLE_CONTROLLER_BIND=127.0.0.1
ENV WADDLE_CONTROLLER_DATA_DIR=/var/lib/waddle-controller
ENV WADDLE_CONTROLLER_AUTH_ENABLED=0
EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5199/bff/health >/dev/null || exit 1
CMD ["/docker-entrypoint.sh"]
