# syntax=docker/dockerfile:1
# Cliente web de CircleGuard: Expo exportado a estáticos y servido por nginx sin privilegios,
# que además hace de reverse proxy hacia los servicios (/api/<servicio>/...).
# Se construye desde la RAÍZ del repo:  docker build -f mobile/Dockerfile -t circleguard-web:<versión> .

# --- Etapa 1: export web de Expo --------------------------------------------------
FROM node:22-alpine AS build
WORKDIR /app
COPY mobile/package.json mobile/package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --no-audit --no-fund --loglevel=error
COPY mobile/ ./
RUN npx expo export -p web --output-dir dist

# --- Etapa 2: nginx sin privilegios (usuario nginx, puerto 8080) ------------------
FROM nginxinc/nginx-unprivileged:1.27-alpine
# Upstreams por variable: la misma imagen sirve en dev, stage y prod (y en Kubernetes con otro resolver).
ENV NGINX_RESOLVER=127.0.0.11 \
    AUTH_UPSTREAM=auth:8180 \
    IDENTITY_UPSTREAM=identity:8083 \
    FORM_UPSTREAM=form:8086 \
    PROMOTION_UPSTREAM=promotion:8088 \
    GATEWAY_UPSTREAM=gateway:8087 \
    DASHBOARD_UPSTREAM=dashboard:8084 \
    FILE_UPSTREAM=file:8085 \
    NOTIFICATION_UPSTREAM=notification:8082
COPY mobile/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
