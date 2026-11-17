# nginx-rtmp

[![Build, test and publish](https://github.com/v1ct0rjs/nginx-rtmp/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/v1ct0rjs/nginx-rtmp/actions/workflows/docker-publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/10t4cl3/nginx-rtmp)](https://hub.docker.com/r/10t4cl3/nginx-rtmp)

A small, maintained Docker image that receives a live stream from **OBS** (or
any RTMP encoder) and serves it as **HLS** for web players, VLC, Second Life
and anything else that plays `.m3u8`.

- **No transcoding.** The HLS segments are cut straight from the incoming
  stream, so the server uses almost no CPU.
- **Always patched.** Built from the official Alpine packages (`nginx` and
  `nginx-mod-rtmp`) and rebuilt every week, so security fixes land
  automatically.
- **Tested before publishing.** Every build streams a test video over RTMP and
  checks that HLS comes out. A broken image is never pushed.
- **`amd64` and `arm64`.** Runs on a regular VPS, an Oracle Cloud Ampere
  instance or a Raspberry Pi 4/5 with a 64-bit OS.
- **Drop-in replacement for [`alfg/nginx-rtmp`](https://github.com/alfg/docker-nginx-rtmp)**,
  which has not been updated since 2022.

```
 OBS ──RTMP:1935──▶  nginx-rtmp  ──HTTP──▶  /live/<name>/index.m3u8  ──▶  viewers
                    (cuts HLS)              /stat  (live statistics)
```

## Contents

1. [Requirements](#requirements)
2. [Installation from Git (step by step)](#installation-from-git-step-by-step)
3. [Using the prebuilt image (without Git)](#using-the-prebuilt-image-without-git)
4. [Protect your stream with a publish key](#protect-your-stream-with-a-publish-key)
5. [HTTPS and your own domain](#https-and-your-own-domain)
6. [Recommended OBS settings](#recommended-obs-settings)
7. [Configuration reference](#configuration-reference)
8. [Updating](#updating)
9. [Migrating from alfg/nginx-rtmp](#migrating-from-alfgnginx-rtmp)
10. [Troubleshooting](#troubleshooting)
11. [Maintaining your own fork](#maintaining-your-own-fork)
12. [License](#license)

## Requirements

- A Linux server (VPS, home server, Raspberry Pi...) with an `amd64` or
  `arm64` CPU.
- **Docker Engine 23 or newer** with the **Compose plugin** (`docker compose`).
- Port **1935/tcp** open to the internet for OBS, plus a port for viewers
  (8080 in the examples, or 80/443 behind a reverse proxy).

## Installation from Git (step by step)

### 1. Install Docker

Skip this step if `docker compose version` already works.

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"
```

Log out and back in so the group change takes effect, then check:

```bash
docker compose version
```

### 2. Download the project

```bash
git clone https://github.com/v1ct0rjs/nginx-rtmp.git
cd nginx-rtmp
```

### 3. Build and start the server

```bash
docker compose up -d --build
```

The first build takes a minute. Check that it is running:

```bash
docker compose ps                     # STATUS should say "Up" (and later "healthy")
docker compose logs --tail 20         # no "emerg" or "ERROR" lines
curl -I http://localhost:8080/stat    # HTTP/1.1 200 OK
```

### 4. Open the firewall

If your server uses `ufw`:

```bash
sudo ufw allow 1935/tcp   # OBS
sudo ufw allow 8080/tcp   # viewers (not needed if you use HTTPS, see below)
```

On a cloud provider (Oracle Cloud, AWS, Hetzner...) also open the same ports
in its web firewall (security list or security group).

### 5. Stream from OBS

In OBS go to **Settings → Stream**:

| Field | Value |
|---|---|
| Service | `Custom...` |
| Server | `rtmp://YOUR_SERVER_IP:1935/stream` |
| Stream Key | any name, e.g. `mystream` |

Then apply the [recommended OBS settings](#recommended-obs-settings) and click
**Start Streaming**.

> [!WARNING]
> Anyone who knows your server address can stream to it until you add a
> publish key. Do it before you go public:
> [Protect your stream with a publish key](#protect-your-stream-with-a-publish-key).

### 6. Watch the stream

The HLS playlist appears a few seconds after OBS starts streaming:

```
http://YOUR_SERVER_IP:8080/live/mystream/index.m3u8
```

- **VLC:** *Media → Open Network Stream* and paste the URL.
- **Safari, iPhone, iPad:** open the URL directly.
- **Chrome, Firefox, Edge:** need an HLS web player such as
  [hls.js](https://github.com/video-dev/hls.js). You can host your own player
  page (see [Your own web pages](#your-own-web-pages)).

Live statistics (connected clients, bitrate, resolution):

```
http://YOUR_SERVER_IP:8080/stat
```

That's it. To stop the server run `docker compose down`; to start it again,
`docker compose up -d`.

## Using the prebuilt image (without Git)

If you don't want to build anything, use the image published on Docker Hub.
Create a folder with this `docker-compose.yml` and run `docker compose up -d`:

```yaml
services:
  nginx-rtmp:
    image: 10t4cl3/nginx-rtmp:latest
    container_name: nginx_rtmp
    restart: unless-stopped
    ports:
      - "1935:1935"
      - "8080:80"
```

Or with plain Docker:

```bash
docker run -d --name nginx_rtmp --restart unless-stopped \
  -p 1935:1935 -p 8080:80 10t4cl3/nginx-rtmp:latest
```

The sections below work the same way: copy `examples/nginx-auth.conf.template`
from this repository and add the `volumes:` lines directly to your
`docker-compose.yml`.

## Protect your stream with a publish key

With a publish key, the server only accepts streams that carry your secret.
Nobody else can stream to your server or replace your stream, and the raw
RTMP stream can no longer be pulled (viewers keep using HLS).

The stream **name** doesn't change, so your HLS URL stays the same. Only the
OBS stream key gets the secret appended.

**1. Create your configuration from the example and generate a secret.**
Run this inside the `nginx-rtmp` folder:

```bash
cp examples/nginx-auth.conf.template my-nginx.conf.template
sed -i "s/CHANGE_ME_SECRET/$(openssl rand -hex 16)/" my-nginx.conf.template
grep -o 'arg_key = "[^"]*"' my-nginx.conf.template    # shows your secret
```

Save the secret in a password manager. `my-nginx.conf.template` is listed in
`.gitignore`, so it is never committed.

**2. Tell Docker to use it.** Create `docker-compose.override.yml` (also
ignored by git) next to `docker-compose.yml`:

```yaml
services:
  nginx-rtmp:
    volumes:
      - ./my-nginx.conf.template:/etc/nginx/nginx.conf.template:ro
```

Docker Compose reads this file automatically and merges it with
`docker-compose.yml`.

**3. Restart:**

```bash
docker compose up -d
docker compose logs --tail 5
```

**4. Update OBS.** Keep the same server and change the stream key to:

```
mystream?key=YOUR_SECRET
```

**5. Test it** (optional). Streaming without the key must now fail:

```bash
docker run --rm --network host linuxserver/ffmpeg -nostdin -loglevel error -re \
  -f lavfi -i testsrc2=size=640x360:rate=30 -c:v libx264 -preset veryfast -g 120 -bf 0 -t 5 \
  -f flv rtmp://localhost:1935/stream/test; echo "exit code: $?"   # not 0 = rejected
```

To change the secret, edit the `arg_key` line in `my-nginx.conf.template` and
run `docker compose restart`.

> [!NOTE]
> The container refuses to start while the example placeholder is still in
> the file, so you can't go live with the example secret by mistake.

## HTTPS and your own domain

Browsers block HTTP video inside HTTPS pages, and many platforms (Second Life
media on prims, for example) work best with HTTPS. Put a reverse proxy in
front of the HTTP port. **RTMP (port 1935) does not go through the proxy**:
OBS keeps connecting directly to `rtmp://stream.example.com:1935/stream`.

First, create a DNS **A record** (`stream.example.com` → your server IP).

### Option A: Caddy (simplest, if nothing else uses ports 80 and 443)

Caddy gets and renews the Let's Encrypt certificate by itself. Create a
`Caddyfile` in the project folder:

```
stream.example.com {
    reverse_proxy nginx-rtmp:80
}
```

And this `docker-compose.override.yml` (if you already have one for the
publish key, add these lines to it):

```yaml
services:
  nginx-rtmp:
    ports: !override
      - "1935:1935"        # HTTP is now served only through Caddy

  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data

volumes:
  caddy_data:
```

```bash
docker compose up -d
sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
```

Your stream is now at `https://stream.example.com/live/mystream/index.m3u8`.

`!override` needs Docker Compose 2.24.4 or newer. On older versions, leave
the port as it is and keep 8080 closed in the firewall.

### Option B: Traefik (if you already run it)

Add the container to Traefik's network and give it labels, for example in
`docker-compose.override.yml`:

```yaml
services:
  nginx-rtmp:
    ports: !override
      - "1935:1935"
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rtmp-web.rule=Host(`stream.example.com`)"
      - "traefik.http.routers.rtmp-web.entrypoints=websecure"
      - "traefik.http.routers.rtmp-web.tls.certresolver=letsencrypt"
      - "traefik.http.services.rtmp-web.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
```

Change `proxy`, `websecure` and `letsencrypt` to the network, entrypoint and
certificate resolver names of your Traefik setup.

### Option C: a server that already has a web panel

If ports 80 and 443 are taken by another application (AzuraCast or a control
panel, for example), use that application's reverse proxy feature, or keep
the image on its own port (`8080`) and serve HLS over plain HTTP.

## Recommended OBS settings

The server doesn't re-encode, so OBS must send a stream that is already HLS
friendly. The first two settings matter most:

| Setting | Value | Why |
|---|---|---|
| **Keyframe Interval** (Output) | `4` s | Must match the 4 s HLS fragment. Other values cause micro-freezes. |
| **B-frames** (Output) | `0` | B-frames are the most common cause of stuttering with HLS pass-through. |
| Rate Control (Output) | `CBR` | Steady bandwidth for viewers. |
| Bitrate (Output) | 2500–6000 Kbps | Depends on your upload speed and resolution. |
| Look-ahead (Output) | Disabled | |
| Resolution / FPS (Video) | 1920x1080 or 1280x720, **30 FPS** | |
| Audio | 44.1 or 48 kHz, stereo | |

Use *Settings → Output → Output Mode: Advanced* to see all of them, and
disable *Settings → Advanced → Network → Dynamically change bitrate*.

## Configuration reference

### Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `RTMP_PORT` | `1935` | RTMP port inside the container |
| `HTTP_PORT` | `80` | HTTP port inside the container |

They are substituted into the configuration template when the container
starts (`${RTMP_PORT}` and `${HTTP_PORT}`). Every other `$` variable is left
for nginx.

### Paths inside the container

| Path | Content |
|---|---|
| `/etc/nginx/nginx.conf.template` | Configuration template. Mount your own here. |
| `/www/static` | Web root for your own pages (contains `stat.xsl`). |
| `/opt/data/hls` | HLS playlists and segments (temporary, cleaned automatically). |

### URLs

| URL | What it is |
|---|---|
| `rtmp://HOST:1935/stream/<name>` | Where OBS publishes (`<name>` is the stream key) |
| `http://HOST/live/<name>/index.m3u8` | HLS playlist for viewers |
| `http://HOST/live/<name>.m3u8` | Short form, redirects to the one above |
| `http://HOST/stat` | Live statistics page |

### Your own configuration

The default configuration is [`nginx.conf.template`](nginx.conf.template).
To change it (for example the HLS fragment length or the application name):

```bash
cp nginx.conf.template my-nginx.conf.template
nano my-nginx.conf.template
```

Mount it with `docker-compose.override.yml` exactly as in
[the publish key section](#protect-your-stream-with-a-publish-key) and run
`docker compose up -d`. The RTMP module is loaded automatically, so your file
doesn't need `load_module`. If the configuration has an error, the container
stops and `docker compose logs` shows the file and line.

If you change `hls_fragment`, set the OBS keyframe interval to the same number
of seconds.

### Your own web pages

Put your files (a player page, for example) in a `www/` folder. Copy
`stat.xsl` into it first so `/stat` keeps its formatting:

```bash
mkdir -p www
docker compose cp nginx-rtmp:/www/static/stat.xsl www/
```

Then mount the folder:

```yaml
# docker-compose.override.yml
services:
  nginx-rtmp:
    volumes:
      - ./www:/www/static:ro
```

The files are served at `http://HOST/<file>`, e.g. `http://HOST/player.html`.

## Updating

**Installed from Git:**

```bash
cd nginx-rtmp
git pull
docker compose build --pull
docker compose up -d
```

**Prebuilt image:**

```bash
docker compose pull
docker compose up -d
```

Your own files (`docker-compose.override.yml`, `my-nginx.conf.template`,
`www/`) are ignored by git, so `git pull` never overwrites them.

Viewers see a short interruption while the container restarts; OBS reconnects
by itself.

### Image tags

| Tag | Content |
|---|---|
| `latest` | The latest build |
| `1.30.6` | The latest build with that nginx version |
| `1.30.6-YYYYMMDD` | One specific build (UTC date), to pin an exact image |

## Migrating from alfg/nginx-rtmp

Change only the `image:` line of your `docker-compose.yml`:

```yaml
    image: 10t4cl3/nginx-rtmp:latest   # was: alfg/nginx-rtmp
```

The variables (`RTMP_PORT`, `HTTP_PORT`), the template path
(`/etc/nginx/nginx.conf.template`) and the folders (`/www/static`,
`/opt/data/hls`) are the same, and existing configurations get the RTMP module
loaded automatically.

Differences:

- **No FFmpeg inside.** Configurations that use `exec ffmpeg ...` to transcode
  into several qualities won't work. Configurations that only cut HLS
  (`hls on`) work unchanged.
- If you mount your own `/www/static`, copy `stat.xsl` into it so `/stat`
  keeps its formatting.

## Troubleshooting

**OBS says "Failed to connect to server"**
- Check the server URL: `rtmp://HOST:1935/stream`. The stream name goes in
  *Stream Key*, not in the URL.
- Port 1935/tcp must be open in `ufw` **and** in your cloud provider's
  firewall. Test from your PC: `nc -vz HOST 1935`.
- With a publish key, the stream key must be `name?key=SECRET`, with no
  spaces. Rejected attempts appear in `docker compose logs`.

**The `.m3u8` URL gives 404**
- The playlist exists only while OBS is streaming. Wait about 10 seconds after
  starting the stream.
- Check the name: OBS key `mystream` → `/live/mystream/index.m3u8`.

**The video freezes every few seconds**
- The keyframe interval must be exactly 4 s and B-frames must be 0 (see
  [Recommended OBS settings](#recommended-obs-settings)).
- If OBS shows dropped frames, lower the bitrate.

**`/stat` shows raw XML without formatting**
- Your mounted `www/` folder is missing `stat.xsl`. Copy it as shown in
  [Your own web pages](#your-own-web-pages).

**The container restarts in a loop**
- `docker compose logs` shows why: a configuration error (with file and line),
  or the example placeholder still in your template.

### Security notes

- `/stat` is public and shows the IP addresses of connected clients. If you
  don't want that, remove the `location /stat` block from your template.
- Docker publishes container ports through its own iptables rules, which
  **bypass `ufw`**. If a port must stay private, don't publish it in `ports:`,
  or bind it to localhost (`"127.0.0.1:8080:80"`).

## Maintaining your own fork

The GitHub Action in
[`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml)
rebuilds the image on every push to `main`, every Monday and on demand. It:

1. Builds the image from scratch with the latest Alpine packages.
2. Streams a test video with FFmpeg and checks that HLS is produced.
3. Checks that the publish key example rejects streams without the key and
   accepts streams with it.
4. Publishes `linux/amd64` and `linux/arm64` images to Docker Hub, only if all
   tests passed.

Dependabot opens a pull request when a new Alpine release or a new version of
the GitHub Actions is available.

To publish to your own Docker Hub account:

1. Fork this repository.
2. Docker Hub → *Account settings* → *Personal access tokens*: create a token
   with *Read & Write* permission.
3. GitHub → your fork → *Settings* → *Secrets and variables* → *Actions*:
   - **Variables** tab: `DOCKERHUB_USERNAME` = your Docker Hub user name.
   - **Secrets** tab: `DOCKERHUB_TOKEN` = the token from step 2.
4. *Actions* tab → *Build, test and publish* → *Run workflow*.

To build and push by hand instead:

```bash
docker build --pull --no-cache -t YOUR_USER/nginx-rtmp:latest .
docker login
docker push YOUR_USER/nginx-rtmp:latest
```

## License

The RTMP module and `static/stat.xsl` are by Roman Arutyunyan and are
distributed under the BSD-2-Clause license (see
[`THIRD_PARTY_LICENSE-nginx-rtmp-module`](THIRD_PARTY_LICENSE-nginx-rtmp-module)).
nginx and Alpine Linux are distributed under their own licenses.
