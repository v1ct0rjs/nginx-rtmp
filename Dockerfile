# syntax=docker/dockerfile:1
#
# Servidor RTMP -> HLS sin recodificar (OBS -> HLS).
# nginx + nginx-rtmp-module usando los paquetes oficiales de Alpine:
# no se compila nada y cada reconstrucción recoge los parches de seguridad.
#
# Compatible con alfg/nginx-rtmp: mismas rutas, mismas variables
# (RTMP_PORT, HTTP_PORT) y la misma plantilla /etc/nginx/nginx.conf.template.

FROM alpine:3.24

LABEL org.opencontainers.image.title="nginx-rtmp" \
      org.opencontainers.image.description="RTMP -> HLS sin recodificar: nginx + nginx-rtmp-module (paquetes oficiales de Alpine)" \
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

# Comprueba que el puerto RTMP acepta conexiones (sin llenar el log de accesos HTTP).
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
  CMD nc -z 127.0.0.1 "${RTMP_PORT}" || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx"]
