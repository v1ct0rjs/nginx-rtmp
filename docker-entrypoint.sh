#!/bin/sh
# Genera /etc/nginx/nginx.conf a partir de la plantilla, igual que hacía
# alfg/nginx-rtmp, y arranca nginx en primer plano.
set -eu

: "${RTMP_PORT:=1935}"
: "${HTTP_PORT:=80}"
export RTMP_PORT HTTP_PORT

TEMPLATE=/etc/nginx/nginx.conf.template
CONF=/etc/nginx/nginx.conf

# Si se pide otro comando (por ejemplo "sh"), ejecutarlo tal cual.
if [ "$#" -gt 0 ] && [ "$1" != "nginx" ]; then
  exec "$@"
fi

{
  # El módulo RTMP es un módulo dinámico de Alpine: se carga aquí salvo que
  # la plantilla ya lo haga, así no hace falta tocar configuraciones antiguas.
  if ! grep -Eq 'ngx_rtmp_module|modules/\*\.conf' "$TEMPLATE"; then
    echo 'include /etc/nginx/modules/*.conf;'
  fi
  # Solo se sustituyen estas variables: el resto de "$" de la configuración
  # de nginx ($1, $uri...) se respetan.
  envsubst '${RTMP_PORT} ${HTTP_PORT}' < "$TEMPLATE"
} > "$CONF"

mkdir -p /opt/data/hls
chown nginx:nginx /opt/data/hls

nginx -t -q

if grep -Eq '^[[:space:]]*daemon[[:space:]]+off' "$CONF"; then
  exec nginx
else
  exec nginx -g 'daemon off;'
fi
