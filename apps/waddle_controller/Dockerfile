# syntax=docker/dockerfile:1
# nginx :443 (self-signed) -> static SPA + proxy /bff -> Node BFF :5199 (HTTP loopback).
# Build from repository root: docker build -f apps/waddle_controller/Dockerfile .

# glibc builder: native addons ship linux-x64 prebuilds (Alpine musl often misses them).
FROM node:22-bookworm-slim AS build
# Official node images default NODE_ENV=production, which omits devDependencies (tsc, vite).
ENV NODE_ENV=development
ARG WADDLE_CONTROLLER_BUILD_NUMBER=dev
ENV WADDLE_CONTROLLER_BUILD_NUMBER=$WADDLE_CONTROLLER_BUILD_NUMBER
ENV WADDLE_NODE_TLS_ROOT=/waddle-repo/packages/waddle_node_tls
ENV WADDLE_VIEW_REPO_ROOT=/waddle-repo
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    python3 make g++ libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*
# Keep monorepo paths so package-lock.json file:../../packages/waddle_node_tls resolves for npm ci.
WORKDIR /waddle-repo
COPY packages/waddle_node_tls packages/waddle_node_tls
RUN npm ci --prefix packages/waddle_node_tls
COPY apps/waddle_controller/package.json apps/waddle_controller/package-lock.json apps/waddle_controller/
WORKDIR /waddle-repo/apps/waddle_controller
RUN test -s package-lock.json \
  && node -e "const p=require('./package-lock.json'); if (!p.lockfileVersion) process.exit(1)"
RUN npm ci --ignore-scripts
COPY apps/waddle_controller/ .
COPY LICENSE /waddle-repo/LICENSE
RUN npm run postinstall \
  && npm run build \
  && npm run build:server \
  && mkdir -p /waddle-repo/packages/waddle_node_tls/dist \
  && ./node_modules/.bin/tsc \
    --ignoreConfig \
    --module NodeNext \
    --moduleResolution NodeNext \
    --target ES2022 \
    --rootDir /waddle-repo/packages/waddle_node_tls/src \
    --outDir /waddle-repo/packages/waddle_node_tls/dist \
    /waddle-repo/packages/waddle_node_tls/src/index.ts \
    /waddle-repo/packages/waddle_node_tls/src/envFlag.ts \
    /waddle-repo/packages/waddle_node_tls/src/resolveTls.ts \
    /waddle-repo/packages/waddle_node_tls/src/selfSigned.ts \
  && node -e "const fs=require('fs'); const p='/waddle-repo/packages/waddle_node_tls/package.json'; const j=JSON.parse(fs.readFileSync(p,'utf8')); j.exports='./dist/index.js'; fs.writeFileSync(p, JSON.stringify(j,null,2)+'\n');" \
  && npm prune --omit=dev \
  && npm rebuild better-sqlite3 @node-rs/argon2 \
  && rm -rf node_modules/@waddle/node-tls \
  && mkdir -p node_modules/@waddle \
  && cp -a /waddle-repo/packages/waddle_node_tls node_modules/@waddle/node-tls \
  && rm -rf node_modules/@waddle/node-tls/node_modules \
  && npm ci --omit=dev --prefix node_modules/@waddle/node-tls

FROM node:22-bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends nginx openssl wget ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /waddle-repo/apps/waddle_controller/package.json ./
COPY --from=build /waddle-repo/apps/waddle_controller/node_modules ./node_modules
COPY --from=build /waddle-repo/apps/waddle_controller/dist /usr/share/nginx/html
COPY --from=build /waddle-repo/apps/waddle_controller/server/dist ./server/dist
# SQL migrations are not emitted by tsc; runtime looks beside dist/db via import.meta.url.
COPY --from=build /waddle-repo/apps/waddle_controller/server/src/db/migrations ./server/dist/db/migrations
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
