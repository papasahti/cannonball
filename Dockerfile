FROM dart:3.11-sdk AS build

WORKDIR /app

COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN mkdir -p /app/build \
    && dart compile exe bin/server.dart -o /app/build/cannonball

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --home /app --shell /usr/sbin/nologin cannonball \
    && mkdir -p /app/web /app/docker /data \
    && chown -R cannonball:cannonball /app /data

WORKDIR /app

COPY --from=build /runtime/ /
COPY --from=build /app/build/cannonball /app/cannonball
COPY web /app/web
COPY docker/entrypoint.sh /app/docker/entrypoint.sh

RUN chmod +x /app/docker/entrypoint.sh

USER cannonball

ENV PORT=8080 \
    DATABASE_DRIVER=sqlite \
    DATABASE_PATH=/data/cannonball.db \
    APP_WEB_ROOT=/app/web

VOLUME ["/data"]

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:8080/health >/dev/null || exit 1

ENTRYPOINT ["/app/docker/entrypoint.sh"]
