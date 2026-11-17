# nginx-rtmp

Servidor RTMP que recibe la emisión de OBS y la convierte a HLS **sin
recodificar** (uso de CPU mínimo), listo para reproductores web y para
Second Life (MOAP).

Sustituto directo de `alfg/nginx-rtmp`, que dejó de mantenerse en 2022
(nginx 1.23.1 y OpenSSL 1.1.1, ya sin parches).

## Qué lleva

| Componente | Origen |
|---|---|
| Alpine Linux 3.24 | imagen oficial `alpine` |
| nginx (rama estable) | paquete oficial de Alpine `nginx` |
| nginx-rtmp-module 1.2.2 | paquete oficial de Alpine `nginx-mod-rtmp` |
| envsubst | paquete de Alpine `gettext-envsubst` |

No se compila nada: al reconstruir la imagen se instalan las últimas
versiones parcheadas que publique Alpine. No incluye FFmpeg, porque la
configuración convierte a HLS sin recodificar.

## Compatibilidad con alfg/nginx-rtmp

Basta con cambiar la línea `image:` del `docker-compose.yml`. Se mantienen:

- Las variables `RTMP_PORT` (1935) y `HTTP_PORT` (80).
- La plantilla `/etc/nginx/nginx.conf.template`, en la que se sustituyen
  `${RTMP_PORT}` y `${HTTP_PORT}` al arrancar.
- La carpeta de archivos estáticos `/www/static` y la de HLS `/opt/data/hls`.

El módulo RTMP se carga automáticamente, así que las configuraciones de
`alfg/nginx-rtmp` funcionan sin añadir `load_module`.

## Uso

```yaml
services:
  nginx-rtmp:
    image: TU_USUARIO/nginx-rtmp:latest
    container_name: nginx_rtmp
    restart: unless-stopped
    ports:
      - "1935:1935"
    environment:
      - RTMP_PORT=1935
      - HTTP_PORT=80
    volumes:
      - ./www:/www/static
      - ./nginx.conf:/etc/nginx/nginx.conf.template
```

- OBS: `rtmp://SERVIDOR:1935/stream` con la clave que quieras (por ejemplo `octopus`).
- HLS: `http://SERVIDOR/live/<clave>/index.m3u8`
- Estadísticas: `http://SERVIDOR/stat`

Si montas tu propia carpeta en `/www/static`, copia en ella `static/stat.xsl`
para que la página `/stat` se vea con formato.

### Ajustes recomendados en OBS

Fragmento HLS de 4 s: **intervalo de fotogramas clave de 4 s** y **B-frames a 0**.
Con otros valores la emisión da microcortes.

## Etiquetas

| Etiqueta | Contenido |
|---|---|
| `latest` | La última construcción |
| `1.30.6` | Última construcción con esa versión de nginx |
| `1.30.6-20261123` | Construcción concreta (fecha UTC), para fijar una versión exacta |

## Mantenimiento

La acción de GitHub `.github/workflows/docker-publish.yml`:

1. Se ejecuta con cada cambio en `main`, cada lunes y a mano.
2. Construye la imagen desde cero, descargando los últimos paquetes de Alpine.
3. **La prueba**: emite un vídeo de prueba por RTMP con FFmpeg y comprueba
   que sale el HLS. Si falla, no publica nada.
4. Publica en Docker Hub para `amd64` y `arm64`.

Dependabot avisa con un pull request cuando sale una versión nueva de Alpine.

### Configuración (una sola vez)

1. Docker Hub → *Account settings* → *Personal access tokens* → crea un
   token con permiso *Read & Write*.
2. GitHub → el repositorio → *Settings* → *Secrets and variables* → *Actions*:
   - Pestaña **Variables**: `DOCKERHUB_USERNAME` = tu usuario de Docker Hub.
   - Pestaña **Secrets**: `DOCKERHUB_TOKEN` = el token del paso 1.

### Publicar a mano

```bash
docker build --pull --no-cache -t TU_USUARIO/nginx-rtmp:latest .
docker login
docker push TU_USUARIO/nginx-rtmp:latest
```

## Licencia

El módulo RTMP y `static/stat.xsl` son de Roman Arutyunyan, con licencia
BSD-2-Clause (ver `THIRD_PARTY_LICENSE-nginx-rtmp-module`).
