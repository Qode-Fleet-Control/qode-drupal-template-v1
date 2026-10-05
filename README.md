# Drupal template

Provisioned from [`Qode-Fleet-Control/fleet-template-v1`](https://github.com/Qode-Fleet-Control/fleet-template-v1) — the fleet
lifecycle contract (`bin/`, `fleet.conf`, `compose.yaml`, deploy workflows) with the
official `drupal/recommended-project` (Drupal 11) plus Drush laid on top, served by
FrankenPHP. The site installs itself on first start — no browser installer.

## Origin

    docker run --rm -u $(id -u):$(id -g) -v "$PWD":/w -w /w <php8.4 + composer:2 image> \
      composer create-project drupal/recommended-project qode-drupal-template-v1 --prefer-dist --no-interaction
    # then, in the project:
    composer require drush/drush --no-interaction

Generated 2026-10-05 (drupal/core-recommended ^11.4, drush/drush ^13.8, PHP 8.4.26).
Composer-managed directories (`vendor/`, `web/core/`) were removed; `composer.lock` and
the drupal-scaffold files under `web/` (`index.php`, `.htaccess`, `autoload.php`, …) are
kept.

## Run it

**On the fleet** — nothing to do: `bin/run` (docker runtime) does `docker compose build`
then `docker compose up --remove-orphans` in the foreground. On start the container runs
`drush site:install standard` (first start only) and serves `0.0.0.0:$PORT`;
`HEALTH_PATH=/` (the front page, 200 once installed). The admin login is
`admin` / `$DRUPAL_ADMIN_PASSWORD` — or, when that is unset, a generated password printed
in the container log (`prepare: admin user 'admin', generated password: …`).

**With docker**

    PORT=8080 bin/run              # or: docker compose up --build
    curl localhost:8080/

**Without docker** (PHP 8.3+ with gd and pdo_sqlite on SQLite >= 3.45, composer):

    FLEET_RUNTIME=process PORT=8080 bin/run
    # = composer install; docker/prepare.sh (site:install); vendor/bin/drush runserver 0.0.0.0:$PORT

| step | process runtime | docker runtime |
|---|---|---|
| install | `composer install --no-interaction` | — |
| build | `docker/prepare.sh` | `docker compose build` |
| start | `vendor/bin/drush runserver 0.0.0.0:$PORT` | `docker compose up --remove-orphans` |

## Database and state

- **SQLite by default**, at `private/drupal.sqlite` (outside the docroot); **Postgres when
  `DATABASE_URL` is set** — the fleet's shared Postgres. Both are wired in
  `web/sites/default/settings.php`, which reads everything from the environment.
- `compose.yaml` mounts two volumes: `drupal-private` (`private/`: SQLite file, generated
  hash salt, private files) and `drupal-files` (`web/sites/default/files`). They survive
  `docker compose down`, so a restart reuses the installed site (`drush updatedb` +
  `cache:rebuild` only); `docker compose down -v` starts over.
- Settings from the environment: `DRUPAL_HASH_SALT`, `DRUPAL_ADMIN_USER`,
  `DRUPAL_ADMIN_PASSWORD`, `DRUPAL_SITE_NAME`, `DRUPAL_PROFILE` (default `standard`).

## How the container works

- `Dockerfile`: `dunglas/frankenphp:1-php8.4-trixie` (+ gd, pdo_pgsql, zip, apcu;
  `memory_limit=512M`), `composer install --no-dev` (which also runs drupal-scaffold),
  non-root user `app`. **trixie, not bookworm**: Drupal 11 requires SQLite >= 3.45, and
  bookworm's PHP links SQLite 3.40.
- `docker/entrypoint.sh` → `docker/prepare.sh` (salt, install or update, cache rebuild),
  then FrankenPHP's stock Caddyfile on `SERVER_NAME=":$PORT"`, document root `web/`
  (`php_server` gives Drupal its clean URLs; `.htaccess` is Apache-only).

## Deviations from the stock generator output, and why

- `drush/drush` added — the documented way to install and manage a Composer-built site,
  and what makes the wizard-free install possible.
- `web/sites/default/settings.php` committed (stock `example.gitignore` ignores it): it is
  `default.settings.php` plus a block that takes the database, hash salt, config-sync and
  private paths from the environment, and trusts the fleet edge's forwarded headers when
  `FLEET_APP_URL` is set. It holds no secrets.
- `config/sync/` created (empty) as the config-sync directory.
- Added `.gitignore`, `Dockerfile`, `docker/`, `compose.yaml`, `.dockerignore`,
  `fleet.conf`, `bin/`, `.github/workflows/`, `docs/fleet-lifecycle.md`.

## Verified

**Not verified yet.** The `docker compose build` / `verify.sh` run was never reached: on
2026-10-05 the shared docker host's disk sat at 0-2 GB free (98 GB volume at 99-100%)
for more than three hours, below the 6 GB gate builds wait for. Before trusting this
template, run `verify.sh <dir> <port>` (run, restart and stop must all pass).

What *was* checked: `migrate.py audit` → READY; `php -l` on every PHP file this template
added or changed, and `sh -n` on its shell scripts → clean.

See `docs/fleet-lifecycle.md` for the lifecycle scripts.
