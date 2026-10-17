#!/usr/bin/env bash
# Applies the currently checked-out code: rebuilds the image when Python
# dependencies change, then restarts the web container. The container
# entrypoint runs migrations on start.
#
# Run automatically by babybuddy-deploy.service whenever a `git pull`
# updates the checkout (see babybuddy-deploy.path).
set -euo pipefail

APP_DIR="/workspace/babybuddy"
STATE_DIR="/var/lib/babybuddy"

cd "$APP_DIR"
mkdir -p "$STATE_DIR" "$APP_DIR/data" "$APP_DIR/media"

# Serialize concurrent triggers (path unit, manual runs, install.sh).
exec 9>"$STATE_DIR/deploy.lock"
flock 9

# A `git pull` may still be writing when the ref changes; wait for it.
for _ in $(seq 1 30); do
    [ ! -e "$APP_DIR/.git/index.lock" ] && break
    sleep 1
done

# Rebuild only when the dependency set or the image definition changed.
new_sum="$(cat requirements.txt Dockerfile | sha256sum | cut -d' ' -f1)"
old_sum="$(cat "$STATE_DIR/requirements.sha256" 2>/dev/null || true)"
if [ "$new_sum" != "$old_sum" ]; then
    echo "[deploy] requirements.txt/Dockerfile changed, rebuilding web image"
    docker compose build web
    echo "$new_sum" > "$STATE_DIR/requirements.sha256"
fi

echo "[deploy] Ensuring containers are running"
docker compose up -d --remove-orphans

echo "[deploy] Recreating web container (runs migrations on start)"
docker compose up -d --force-recreate --no-deps web

echo "[deploy] Done at $(date -Is): $(git rev-parse --short HEAD)"
