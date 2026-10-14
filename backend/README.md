# UniLect — Backend API

Django REST Framework backend for a protected academic-content platform:

- **Administrators** build the catalog (universities → faculties → levels → courses → instructors), manage
  accounts, libraries, settings, device-change requests, reports and the audit log.
- **Libraries** upload lectures and past exam papers inside their academic scope and publish them.
- **Students** use a mobile app bound to **one device** to browse, search and *view* (never download) published content.

| Document | Contents |
|---|---|
| [docs/01-requirements-analysis-and-architecture.md](docs/01-requirements-analysis-and-architecture.md) | Requirements analysis, assumptions, architecture & decisions, data model, workflows |
| [docs/02-api-reference.md](docs/02-api-reference.md) | Every endpoint with permissions and validation rules, error format |
| [docs/03-traceability-matrix.md](docs/03-traceability-matrix.md) | FR-001…FR-080 → implementation → tests |
| [docs/04-limitations-and-roadmap.md](docs/04-limitations-and-roadmap.md) | Known limitations, assumptions in force, future work |
| [docs/api/openapi.yaml](docs/api/openapi.yaml) | Generated OpenAPI 3 schema (also live at `/api/v1/docs/`) |

---

## Tech stack

| Component | Choice | Why |
|---|---|---|
| Framework | Django 5.2 LTS, DRF 3.16 | LTS security support until 2028 |
| Database | PostgreSQL 17 | Partial unique constraints, row locks, `pg_trgm` trigram index for search |
| Auth | simplejwt + server-side `AuthSession` | JWTs that can be revoked immediately (logout, device change, disabling) |
| API docs | drf-spectacular | OpenAPI generated from code, validated in CI with `--fail-on-warn` |
| Filtering | django-filter | Declarative filters |
| Uploads | filetype + Pillow + pypdf | Magic-byte and structural validation, pure Python |
| Config | django-environ | All secrets from the environment |
| Search | Own `ArabicSearchFilter` + normalised `search_document` column | Arabic letter variants and diacritics are ignored; one indexed column instead of OR across joins |
| Cache | Redis (production) | Shared throttles, login lockouts and settings cache across workers |
| i18n | Django gettext, `locale/ar` | Every API message available in Arabic (default) and English |
| Tests / lint | pytest, pytest-django, pytest-cov, factory_boy, ruff | Coverage gate 95% (branch) |

No Celery or message broker is needed yet (see limitations doc for when to add one). Redis is used only as a cache.

## Project layout

```
unilect/                 settings (base/dev/test/prod), urls, wsgi/asgi
apps/
  core/                  domain-free infrastructure: error envelope, pagination, Arabic text normalisation + search
                         filter, request-id middleware, JSON logging, deploy checks
  accounts/              User + roles + permission classes, AuthSession, JWT auth class, login lockout,
                         services/{sessions,passwords,admin}.py, profile, admin users
  devices/               StudentDevice, DeviceChangeRequest, binding & approval services
  academics/             University, Faculty, Level, Semester, Specialization, Course, Instructor (+ catalog & admin APIs)
  libraries/             Library + academic scope
  content/               ContentItem (lecture | exam), ContentFile versions, upload validation, workflow,
                         protected delivery, search documents, favorites, course follows, stats
  notifications/         In-app notifications
  reports/               Content reports + action history
  audit/                 Append-only AuditLog + secret scrubbing
  config/                SystemSettings singleton (upload limits, allowed types, review toggle)
  dashboard/             Admin summary (cross-domain, read-only; nothing depends on it)
  maintenance/           Retention jobs: `manage.py purge_expired`
locale/ar/               Arabic translation catalogue (.po source + compiled .mo)
tests/                   pytest suite: API, policy, search, concurrency (threads), edge cases
deploy/nginx.conf        Reference TLS reverse proxy with X-Accel-Redirect protected files
deploy/docker-compose.stack.yml + nginx.local.conf   Production-like local stack (nginx, gunicorn, Postgres, Redis, SMTP)
.github/workflows/ci.yml CI: lint, migrations, schema drift, tests + coverage, deploy checks, image build
Dockerfile               Production image (gunicorn, non-root, healthcheck)
docker-compose.yml       Local PostgreSQL for development
```

Dependencies point one way: `core` imports no domain app; `dashboard` and `maintenance` sit on top.
Each app follows the same layering: **views** (HTTP + permissions) → **services** (write use-cases, transactions,
audit) and **selectors** (read visibility / scope rules) → **models** (schema + DB constraints).

---

## Local development

Prerequisites: Python 3.12+ (tested on 3.13), Docker (for PostgreSQL).

```bash
docker compose up -d db
```

```bash
python -m venv .venv
```

Activate it (`.venv\Scripts\activate` on Windows, `source .venv/bin/activate` elsewhere), then:

```bash
pip install -r requirements/dev.txt
```

```bash
cp .env.example .env
```

Edit `.env` and set `SECRET_KEY` (generate one with
`python -c "import secrets; print(secrets.token_urlsafe(64))"`). The default `DATABASE_URL` matches `docker-compose.yml`.

```bash
python manage.py migrate
```

```bash
python manage.py createsuperuser
```

```bash
python manage.py runserver
```

- API root: `http://127.0.0.1:8000/api/v1/`
- Swagger UI: `http://127.0.0.1:8000/api/v1/docs/` · schema: `/api/v1/schema/`
- Health check: `/health/`
- Django admin (internal, superusers): `/django-admin/` (path configurable via `DJANGO_ADMIN_URL`)

`createsuperuser` creates a user with role `admin`. Every other account is created through `POST /api/v1/admin/users/`.

### Demo data

For local development and manual QA, load a complete demo dataset (catalog, libraries, accounts, published content
with real files, a pending device request, an open report). It refuses to run unless `DEBUG` is on:

```bash
python manage.py seed_demo
```

Every demo account uses the password `UniLect#2026`: `admin@unilect.test`, `library@unilect.test`,
`library.aleppo@unilect.test`, `student@unilect.test` (unbound), `student2@unilect.test` (bound to another device),
`disabled@unilect.test`.

### Running for the mobile app

```bash
python manage.py runserver 0.0.0.0:8000
```

The Android emulator reaches the host as `10.0.2.2` (already in `ALLOWED_HOSTS` of `.env.example`); for a physical
phone add the computer's LAN address. Password-reset emails link to `unilect://app/reset-password?uid=…&token=…`, which
the app opens.

### Mobile app end-to-end tests

The app's `test/live` suite drives its real networking stack against this API. Run it against its own database with the
`e2e` settings (dev settings with relaxed throttling), so your development data is untouched:

```bash
docker compose exec db createdb -U unilect unilect_e2e
```

With `DATABASE_URL=postgres://unilect:unilect-dev-only@127.0.0.1:5432/unilect_e2e` and
`DJANGO_SETTINGS_MODULE=unilect.settings.e2e` set in the shell:

```bash
python manage.py migrate && python manage.py seed_demo
```

```bash
python manage.py runserver 127.0.0.1:8001
```

Then, in `Frontend/unilect`: `UNILECT_API=http://127.0.0.1:8001/api/v1 flutter test test/live`. The suite creates its own
accounts on each run, so it can be repeated without reseeding.

### Typical first-run sequence

1. Log in as the admin: `POST /api/v1/auth/login/ {"email", "password"}`.
2. Create the catalog: universities → faculties → levels/semesters → courses → instructors → course-instructor links.
3. Create lookups: `admin/lecture-categories/`, `admin/exam-types/`.
4. Create a library with a scope (`admin/libraries/`), then a `library` user and `student` users (`admin/users/`).
5. The library uploads (`manage/contents/`) and submits; students browse `catalog/contents/`.

---

## Environment variables

See [.env.example](.env.example). Production-relevant ones:

| Variable | Required in prod | Purpose |
|---|---|---|
| `DJANGO_SETTINGS_MODULE` | yes | `unilect.settings.prod` |
| `SECRET_KEY` | yes | Django signing key |
| `JWT_SIGNING_KEY` | recommended | Separate JWT key (defaults to `SECRET_KEY`); rotating it logs everyone out |
| `DEVICE_ID_HASH_KEY` | recommended | HMAC key for stored device ids. **Changing it unbinds every device** |
| `ALLOWED_HOSTS` | yes | API host names |
| `DATABASE_URL` | yes | `postgres://user:pass@host:5432/db` |
| `CACHE_URL` | yes | `redis://…` so throttles, lockouts and settings are shared between workers |
| `EMAIL_URL`, `DEFAULT_FROM_EMAIL` | yes | SMTP for password reset (`smtp+tls://user:pass@host:587`) |
| `PASSWORD_RESET_URL_TEMPLATE` | yes | Deep link/web page receiving `{uid}` and `{token}` |
| `PRIVATE_MEDIA_ROOT` | yes | Private file directory (never served directly) |
| `PRIVATE_MEDIA_ACCEL_PREFIX` | with nginx | e.g. `/protected-media/` to enable `X-Accel-Redirect` |
| `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` | if a web dashboard exists | Exact origins |
| `NUM_PROXIES` | default 1 | Trusted reverse proxies, for client IP in throttling/audit |
| `LOG_FORMAT` | recommended | `json` for structured logs |
| `JWT_ACCESS_MINUTES`, `JWT_REFRESH_DAYS` | optional | Token lifetimes (default 10 min / 30 days) |
| `SESSION_MAX_DAYS` | optional | Maximum total session age regardless of refreshes (default 90) |
| `RETAIN_*` | optional | Retention for `purge_expired` (see `.env.example`; 0 = keep forever) |
| `SECURE_HSTS_PRELOAD` | optional | Opt in to the HSTS preload list (hard to undo) |

---

## Tests and quality checks

The tests run against PostgreSQL (the same engine as production, so constraints are really exercised).
pytest-django creates and destroys a separate `test_*` database.

```bash
python -m pytest --cov
```

`--cov` prints branch coverage and fails below 95%. `tests/test_concurrency.py` runs real parallel requests on
separate database connections, to exercise the row locks.

```bash
ruff check . && ruff format --check .
```

```bash
python manage.py makemigrations --check --dry-run
```

```bash
python manage.py spectacular --validate --fail-on-warn --file docs/api/openapi.yaml
```

### Last verified run (2026-10-12, Windows 11, Python 3.13.7, PostgreSQL 17 in Docker)

| Check | Result |
|---|---|
| `pytest --cov` | **290 passed**, branch coverage **96.7%** |
| ruff lint + format | clean |
| `makemigrations --check` | no changes |
| `spectacular --validate --fail-on-warn` | 0 warnings |
| `check --deploy --fail-level WARNING` (prod settings, Redis cache) | no issues |
| Production-like stack (`deploy/docker-compose.stack.yml`) | image builds, migrations run, gunicorn healthy, **33/33** end-to-end checks through nginx (below) |

The stack run covered: the full admin → library → student flow; device binding, refusal, change request and
approval; nginx `X-Accel-Redirect` delivery with no header leak and HTTP range requests (206); the internal media
path is unreachable directly; Arabic error messages; a password-reset email delivered over real SMTP (Mailpit);
the audit log records the client IP as seen by nginx; a spoofed `X-Forwarded-For` is ignored; JSON logs contain
no passwords, tokens or device IDs; `purge_expired` runs.

The CI workflow (`.github/workflows/ci.yml`) mirrors these commands. It hasn't been run on GitHub yet, because the
repository has no remote.

---

## Database migrations

- `python manage.py migrate` applies everything. `content.0001_pg_trgm` enables the `pg_trgm` extension. It's a
  trusted extension on PostgreSQL 13+, so the database owner can install it. On managed services that restrict
  extensions, enable it once yourself with `CREATE EXTENSION pg_trgm;`.
- Integrity rules live in the database (check constraints, partial unique indexes). When you change a model, run
  `makemigrations` and commit the migration. Use separate data migrations for backfills. Don't edit applied
  migrations.
- Back up the database before migrating in production.
- `content.0003_search_document` adds a column, **backfills it for existing rows**, and swaps the trigram indexes.
  It's safe on existing data. On very large tables, build the index separately with `CREATE INDEX CONCURRENTLY`.

---

## Deployment (reference)

1. Build: `docker build -t unilect-api .` (gunicorn, non-root user, `DJANGO_SETTINGS_MODULE=unilect.settings.prod`).
2. Provide the environment variables above. Mount `PRIVATE_MEDIA_ROOT` on persistent storage that the API
   container writes to and nginx reads from.
3. Run `python manage.py migrate` as a release step, then start the container.
4. Put nginx in front, using [deploy/nginx.conf](deploy/nginx.conf):
   - TLS termination.
   - `client_max_body_size` at least as large as the upload limit.
   - An `internal` location for `PRIVATE_MEDIA_ACCEL_PREFIX`.
   - Overwrite `X-Forwarded-For`; don't append to it.
5. Use Redis for `CACHE_URL` (required with more than one worker; `check --deploy` warns `unilect.W001` otherwise).
6. Schedule `python manage.py purge_expired` daily (cron or a Kubernetes CronJob). It applies the retention policy for
   ended sessions, read notifications, old file versions and, if enabled, audit logs.
7. Run `python manage.py check --deploy` with production settings. It should report no issues.
8. Swagger and the schema need an admin token in production.

To try the whole production topology locally (nginx, gunicorn, PostgreSQL, Redis, Mailpit SMTP):

```bash
docker compose -f deploy/docker-compose.stack.yml up -d --build
```

The API is then at `http://127.0.0.1:8080/api/v1/` and captured emails at `http://127.0.0.1:8025`.

Security headers (HSTS, SSL redirect, secure cookies, nosniff, `X-Frame-Options: DENY`) are enabled in
`unilect/settings/prod.py`.

---

## Mobile client contract (summary)

- Generate a random **installation id** once per install (16–128 chars, `[A-Za-z0-9_-]`) and keep it in the Android
  Keystore or iOS Keychain.
- Send it as `device.installation_id` in the login request, and as the **`X-Device-ID` header on every request**,
  including token refresh.
- `403 device_not_bound` on login means another device is bound. Use `error.details.device_change_token` as the bearer
  token to call `POST /api/v1/auth/device-change-requests/` from the new device.
- Open files only through `GET /api/v1/catalog/contents/{id}/file/` in the in-app viewer. Overlay `watermark_text`.
  Block screenshots where the OS allows it (`FLAG_SECURE` on Android). These are client responsibilities.
- Branch on `error.code`, never on `error.message`.
