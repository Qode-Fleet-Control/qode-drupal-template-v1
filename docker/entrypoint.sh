#!/bin/sh
# Container start: install/update the site (docker/prepare.sh), then serve it on
# 0.0.0.0:$PORT, the PORT read from the environment now, not at build time.
set -e
docker/prepare.sh
export SERVER_NAME=":${PORT:-8080}"
exec frankenphp run --config /etc/frankenphp/Caddyfile
