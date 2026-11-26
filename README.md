# docker-laravel-stack

A production-shaped Docker Compose stack for Laravel: PHP-FPM, nginx, MySQL,
Redis, a queue worker and the scheduler, with health checks wired between them.

Drop it into an existing Laravel project root. Nothing in here is application
code, so it stays out of the way.

## What you get

```
                    ┌──────────────────────────────┐
   :80 / :443  ───▶ │ nginx                        │
                    │  static assets, healthz      │
                    └──────────────┬───────────────┘
                                   │ fastcgi :9000
                    ┌──────────────▼───────────────┐
                    │ app  (php-fpm)               │
                    │  opcache + JIT               │
                    └──┬────────────────────────┬──┘
                       │                        │
             ┌─────────▼────────┐     ┌─────────▼─────────┐
             │ queue            │     │ scheduler         │
             │ queue:work       │     │ schedule:work     │
             └─────────┬────────┘     └─────────┬─────────┘
                       │   internal network     │
             ┌─────────▼──────────┐   ┌─────────▼─────────┐
             │ mysql 8.4          │   │ redis 8           │
             │ healthcheck: ping  │   │ healthcheck: ping │
             └────────────────────┘   └───────────────────┘
```

Only nginx is published to the host. MySQL and Redis sit on a network declared
`internal: true`, so they have no route off the host even if a container is
compromised.

## Services

| Service | Image | Purpose |
|---|---|---|
| `app` | built from `docker/php/Dockerfile` | PHP-FPM, application code |
| `nginx` | `nginx:1.29-alpine` | TLS termination, static assets, FastCGI proxy |
| `queue` | same image as `app` | `queue:work`, restarts hourly to bound memory |
| `scheduler` | same image as `app` | `schedule:work`, one instance only |
| `db` | `mysql:8.4` | primary database |
| `redis` | `redis:8-alpine` | cache, sessions, queue backend |

## Quick start

```bash
cp .env.example .env

# Fill in the blanks — the stack refuses to start without them
#   DB_PASSWORD, DB_ROOT_PASSWORD, REDIS_PASSWORD, APP_KEY
php artisan key:generate --show     # if you do not have an APP_KEY yet

make build
make up
make migrate
```

Open http://localhost. `make help` lists every target.

## Make targets

```
make up          start the stack
make down        stop it
make logs        follow logs (make logs SERVICE=queue)
make shell       shell into the app container
make artisan     make artisan CMD="route:list"
make migrate     run migrations
make fresh       drop, migrate and seed
make test        run the test suite
make queue-restart   graceful worker restart after a deploy
```

## Design notes

**Multi-stage build, no build tools in the runtime image.** `vendor/` is
installed by the Composer stage and front-end assets by the Node stage; the
runtime image copies only the results. The result has no npm, no Composer dev
dependencies and no source maps.

**OPcache has timestamp validation off by default.** Correct for an image where
code is baked in at build time — a changed file cannot be silently served from a
stale cache. The compose override bind-mounts the source for local development,
so set `opcache.validate_timestamps=1` there (it is commented in
`docker/php/opcache.ini`).

**Health checks are real, not `curl localhost`.** The app exposes an FPM ping
path and the health check speaks FastCGI to it, so a worker pool that is up but
not accepting connections still fails. `nginx` will not start accepting traffic
until `app` reports healthy, and `app` waits on `db` and `redis`.

**The queue worker is time-bounded.** `--max-time=3600 --max-jobs=1000` plus
`restart: unless-stopped` means a slow memory leak in a job cannot accumulate
for a month. Restart workers explicitly on deploy with `make queue-restart` so
they pick up new code.

**One scheduler instance.** `schedule:work` runs a loop; two containers would
run every scheduled task twice. Do not scale this service.

**Secrets come from `.env`, never from the compose file.** Variables with no
sensible default use `${VAR:?message}` so the stack refuses to start rather than
silently running with an empty password.

## TLS

`docker/certs` is mounted read-only into nginx. Point `CERT_DIR` at a directory
containing `fullchain.pem` and `privkey.pem` (certbot, or a managed certificate).
A separate 443 server block is intentionally not included: termination strategy
differs per deployment, and a half-configured TLS block is worse than none.

## Deploying

```bash
git pull
make build
make up                     # recreates only changed services
make migrate
make queue-restart
```

Brief downtime for the `app` container is normal with this layout. For
zero-downtime, front the stack with a load balancer and stop the old container
after the new one reports healthy.

## Requirements

- Docker Engine 24+ with the Compose v2 plugin
- Laravel 10, 11 or 12 (PHP 8.4 base image)

## Licence

MIT
