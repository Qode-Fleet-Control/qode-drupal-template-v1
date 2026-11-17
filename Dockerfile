# Built by .github/workflows/deploy.yml (context ., file Dockerfile) and pushed
# to Artifact Registry.
#
# Drupal 11 (drupal/recommended-project + drush) on FrankenPHP (a Caddy-based PHP
# app server), docroot web/. The trixie variant, not bookworm: Drupal 11 needs
# SQLite >= 3.45 and bookworm ships 3.40. docker/entrypoint.sh installs the site
# with drush on the first start and serves 0.0.0.0:$PORT, the PORT read from the
# environment when the container STARTS.
FROM dunglas/frankenphp:1-php8.4-trixie AS runtime
RUN install-php-extensions gd pdo_pgsql zip apcu \
 && printf 'memory_limit=512M\n' > "$PHP_INI_DIR/conf.d/zz-drupal.ini"
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
# The second install runs the plugins skipped above (drupal-scaffold writes the web/
# scaffold files, installers place core under web/core).
RUN composer install --no-dev --prefer-dist --no-interaction --optimize-autoloader \
 && useradd -r -u 10001 -d /app app \
 && mkdir -p private/files web/sites/default/files \
 && chown -R app:app private web/sites/default/files /config/caddy /data/caddy
# KEEP THIS: one log line per request (status + duration) is what the workspace Monitoring tab charts.
# docker/request-log.caddyfile turns on Caddy's JSON access log on stdout; the stock Caddyfile
# imports it into its site block through CADDY_SERVER_EXTRA_DIRECTIVES.
COPY docker/request-log.caddyfile /etc/frankenphp/request-log.caddyfile
ENV CADDY_SERVER_EXTRA_DIRECTIVES="import /etc/frankenphp/request-log.caddyfile"
ARG BUILD_ID=""
ENV PORT=8080 SERVER_ROOT=/app/web BUILD_ID=$BUILD_ID
USER app
EXPOSE 8080
ENTRYPOINT ["docker/entrypoint.sh"]
