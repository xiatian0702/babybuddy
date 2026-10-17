#!/bin/sh
# Runs on every container start (including restarts after a git pull), so
# schema changes are applied before gunicorn serves the new code.
set -e

python manage.py migrate --noinput

exec "$@"
