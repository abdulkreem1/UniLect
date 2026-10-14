# Production image: gunicorn behind nginx (see deploy/nginx.conf).
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=unilect.settings.prod     PRIVATE_MEDIA_ROOT=/srv/unilect/private_media     STATIC_ROOT=/srv/unilect/staticfiles

WORKDIR /app
RUN useradd --create-home --uid 10001 app     && mkdir -p /srv/unilect/private_media /srv/unilect/staticfiles     && chown -R app:app /srv/unilect
COPY requirements/base.txt requirements/base.txt
RUN pip install --no-cache-dir -r requirements/base.txt
COPY --chown=app:app . .
RUN SECRET_KEY=build-only ALLOWED_HOSTS=localhost DATABASE_URL=sqlite:////tmp/build.db \
    python manage.py collectstatic --noinput

USER app
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --retries=5     CMD python -c "import urllib.request,sys; sys.exit(urllib.request.urlopen('http://127.0.0.1:8000/health/').status != 200)"
CMD ["gunicorn", "unilect.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60", "--access-logfile", "-"]
