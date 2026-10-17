FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Requirements first so dependency layers are cached across code changes.
COPY requirements.txt ./
ARG PIP_INDEX_URL=https://pypi.org/simple
# requirements.txt pins its own (deprecated) index; drop it so the mirror wins.
RUN sed -i '/^-i /d' requirements.txt \
    && pip install --no-cache-dir --index-url "$PIP_INDEX_URL" -r requirements.txt

# manage.py and wsgi.py do not default this, so provide it in the image.
ENV DJANGO_SETTINGS_MODULE=babybuddy.settings.base

COPY . .

EXPOSE 8000

ENTRYPOINT ["sh", "/app/deploy/docker-entrypoint.sh"]
CMD ["gunicorn", "babybuddy.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
