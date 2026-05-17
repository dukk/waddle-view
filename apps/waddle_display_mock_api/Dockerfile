# syntax=docker/dockerfile:1
# nginx :443 (self-signed) → Node mock API :3000 (HTTP loopback).
# Build from repository root: docker build -f apps/waddle_display_mock_api/Dockerfile .

FROM node:22-alpine AS build
WORKDIR /app
COPY packages/waddle_node_tls /packages/waddle_node_tls
RUN npm ci --prefix /packages/waddle_node_tls
COPY apps/waddle_display_mock_api/package.json apps/waddle_display_mock_api/package-lock.json ./
RUN npm ci
COPY apps/waddle_display_mock_api/tsconfig.json ./
COPY apps/waddle_display_mock_api/src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
RUN apk add --no-cache nginx openssl
WORKDIR /app
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY apps/waddle_display_mock_api/nginx/default.conf /etc/nginx/http.d/default.conf
COPY apps/waddle_display_mock_api/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENV PORT=3000
ENV MOCK_API_KEY=dev-mock-key
EXPOSE 80 443
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/v1/health || exit 1
CMD ["/docker-entrypoint.sh"]
