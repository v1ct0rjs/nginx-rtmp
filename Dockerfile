# syntax=docker/dockerfile:1
#
# RTMP -> HLS server without transcoding (OBS -> HLS).
# nginx + nginx-rtmp-module from the official Alpine packages: nothing is
# compiled, and every rebuild picks up the latest security patches.
#
# Drop-in replacement for alfg/nginx-rtmp: same paths, same variables
# (RTMP_PORT, HTTP_PORT) and the same /etc/nginx/nginx.conf.template.

FROM alpine:3.24

LABEL org.opencontainers.image.title="nginx-rtmp" \
      org.opencontainers.image.description="RTMP to HLS without transcoding: nginx + nginx-rtmp-module (official Alpine packages)" \
      org.opencontainers.image.source="https://github.com/v1ct0rjs/nginx-rtmp" \
      org.opencontainers.image.licenses="BSD-2-Clause"

RUN apk upgrade --no-cache \
 && apk add --no-cache nginx nginx-mod-rtmp \
 && (apk add --no-cache gettext-envsubst || apk add --no-cache gettext) \
 && mkdir -p /opt/data/hls /www/static \
 && chown -R nginx:nginx /opt/data \
 && rm -f /etc/nginx/http.d/default.conf

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY static/ /www/static/
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

ENV RTMP_PORT=1935 \
    HTTP_PORT=80

EXPOSE 1935 80
STOPSIGNAL SIGQUIT

# Checks that the RTMP port accepts connections (without filling the HTTP access log).
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
  CMD nc -z 127.0.0.1 "${RTMP_PORT}" || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx"]
