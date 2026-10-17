#!/usr/bin/env bash
# Applies the currently checked-out code: installs changed Python
# dependencies, runs migrations and restarts the web service.
#
# Run automatically by babybuddy-deploy.service whenever a `git pull`
# updates the checkout (see babybuddy-deploy.path).
set -euo pipefail

APP_DIR="/workspace/babybuddy"
STATE_DIR="/var/lib/babybuddy"
PYTHON="$APP_DIR/.venv/bin/python"

cd "$APP_DIR"
mkdir -p "$STATE_DIR"

# Serialize concurrent triggers (path unit, manual runs, install.sh).
exec 9>"$STATE_DIR/deploy.lock"
flock 9

# A `git pull` may still be writing when the ref changes; wait for it.
for _ in $(seq 1 30); do
    [ ! -e "$APP_DIR/.git/index.lock" ] && break
    sleep 1
done

# Reinstall dependencies only when requirements.txt actually changed.
new_sum="$(sha256sum requirements.txt | cut -d' ' -f1)"
old_sum="$(cat "$STATE_DIR/requirements.sha256" 2>/dev/null || true)"
if [ "$new_sum" != "$old_sum" ]; then
    echo "[deploy] requirements.txt changed, installing Python dependencies"
    "$APP_DIR/.venv/bin/pip" install --disable-pip-version-check -q -r requirements.txt
    echo "$new_sum" > "$STATE_DIR/requirements.sha256"
fi

echo "[deploy] Applying database migrations"
"$PYTHON" manage.py migrate --noinput

echo "[deploy] Restarting babybuddy.service"
systemctl restart babybuddy.service

echo "[deploy] Done at $(date -Is): $(git rev-parse --short HEAD)"
