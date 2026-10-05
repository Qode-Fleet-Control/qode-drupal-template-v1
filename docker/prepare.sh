#!/bin/sh
# Make the Drupal site usable without the browser installer: a hash salt, then
# `drush site:install` on the first start (SQLite in private/, or the fleet's Postgres
# when DATABASE_URL is set — see web/sites/default/settings.php). Idempotent: an
# installed site is only brought up to date (updatedb) and its caches rebuilt.
# Used by docker/entrypoint.sh and by fleet.conf's BUILD_CMD (no-docker runs).
set -e
cd "$(dirname "$0")/.."
drush=vendor/bin/drush

mkdir -p private/files web/sites/default/files
if [ -z "${DRUPAL_HASH_SALT:-}" ] && [ ! -s private/hash_salt.txt ]; then
  php -r 'echo bin2hex(random_bytes(32));' > private/hash_salt.txt
fi

if $drush status --field=bootstrap 2>/dev/null | grep -q Successful; then
  echo "prepare: site already installed"
  $drush updatedb --yes
else
  pass="${DRUPAL_ADMIN_PASSWORD:-}"
  [ -n "$pass" ] || pass="$(php -r 'echo bin2hex(random_bytes(8));')"
  echo "prepare: installing Drupal (profile ${DRUPAL_PROFILE:-standard})"
  $drush site:install "${DRUPAL_PROFILE:-standard}" --yes \
    --site-name="${DRUPAL_SITE_NAME:-Drupal}" \
    --account-name="${DRUPAL_ADMIN_USER:-admin}" --account-pass="$pass"
  if [ -z "${DRUPAL_ADMIN_PASSWORD:-}" ]; then
    echo "prepare: admin user '${DRUPAL_ADMIN_USER:-admin}', generated password: $pass"
  fi
fi
$drush cache:rebuild
