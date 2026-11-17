#!/bin/sh
# Builds /etc/nginx/nginx.conf from the template (same behaviour as
# alfg/nginx-rtmp) and starts nginx in the foreground.
set -eu

: "${RTMP_PORT:=1935}"
: "${HTTP_PORT:=80}"
export RTMP_PORT HTTP_PORT

TEMPLATE=/etc/nginx/nginx.conf.template
CONF=/etc/nginx/nginx.conf

# Any other command (for example "sh") is run as is.
if [ "$#" -gt 0 ] && [ "$1" != "nginx" ]; then
  exec "$@"
fi

# Refuse to start with the example publish secret still in place.
if grep -q 'CHANGE_ME' "$TEMPLATE"; then
  echo "ERROR: $TEMPLATE still contains the CHANGE_ME placeholder." >&2
  echo "       Replace it with your own secret first (see the README)." >&2
  exit 1
fi

{
  # The RTMP module is an Alpine dynamic module. Load it here unless the
  # template already does, so old configurations work unchanged.
  if ! grep -Eq 'ngx_rtmp_module|modules/\*\.conf' "$TEMPLATE"; then
    echo 'include /etc/nginx/modules/*.conf;'
  fi
  # Only these variables are substituted; nginx variables ($1, $uri...)
  # are left untouched.
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
