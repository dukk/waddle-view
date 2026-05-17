# syntax=docker/dockerfile:1
# nginx :443 (self-signed) → static SPA + proxy /bff → Node BFF :5199 (HTTP loopback).
# Build from repository root: docker build -f apps/waddle_controller/Dockerfile .

FROM node:22-alpine AS build
WORKDIR /app
COPY packages/waddle_node_tls /packages/waddle_node_tls
COPY apps/waddle_controller/package.json apps/waddle_controller/package-lock.json ./
RUN npm ci
COPY apps/waddle_controller/ .
RUN npm run build && npm run build:server && npm prune --omit=dev

FROM node:22-alpine
RUN apk add --no-cache nginx openssl wget
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/server/dist ./server/dist
COPY apps/waddle_controller/nginx/default.conf /etc/nginx/http.d/default.conf
COPY apps/waddle_controller/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENV PORT=5199
ENV WADDLE_CONTROLLER_BIND=127.0.0.1
ENV WADDLE_CONTROLLER_DATA_DIR=/var/lib/waddle-controller
ENV WADDLE_CONTROLLER_AUTH_ENABLED=0
EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:5199/bff/health >/dev/null || exit 1
CMD ["/docker-entrypoint.sh"]
