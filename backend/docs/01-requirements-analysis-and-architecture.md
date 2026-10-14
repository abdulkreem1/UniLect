# UniLect Backend — Requirements Analysis & Proposed Architecture

> Status: **Approved and implemented** (2026-10-12). All open questions **[Q-n]** were resolved
> by accepting the proposed defaults **[A-n]** (see [04-limitations-and-roadmap.md](04-limitations-and-roadmap.md)).
> Implementation notes that differ from this original plan:
> - Login identifier is email **or** (student number + university), since numbers are unique per university only.
> - The admin dashboard lives in `apps/content/dashboard.py`; content-review approve/reject are
>   admin-only actions on `/manage/contents/{id}/` rather than a separate `/admin/contents/` resource.
> - Library deletion of content is limited to drafts; admin "hide" = archive.
> - Hardening pass: the dashboard moved to its own `dashboard` app and the retention jobs to a `maintenance` app.
>   Permission classes live in `accounts`, so `core` is domain-free. Content search uses a normalised
>   `search_document` column. Sessions have an absolute lifetime. See 04-limitations-and-roadmap.md §2.

---

## 1. Domain summary

UniLect is a protected academic-content platform:

- **Admin (مدير النظام)** builds the academic catalog (universities → faculties → levels → courses → instructors),
  manages accounts, libraries, settings, device-change requests, reports and the audit log.
- **Library (المكتبة)** is a content provider scoped to part of the catalog. It uploads lectures and past exam
  papers (أسئلة الدورات), classifies them and moves them through a publishing workflow.
- **Student (الطالب)** uses a mobile app (Android/iOS), bound to **exactly one device**, to browse, search, filter
  and *view* (never download) published content inside an in-app viewer.

The two hardest parts are (1) **device binding + session revocation** and (2) **protected file delivery**.
Everything else is a well-understood CRUD + workflow + permissions problem.

---

## 2. Roles

| Role | Created by | Device-bound | Scope |
|---|---|---|---|
| `STUDENT` | Admin | Yes (1 active device) | Reads published content only |
| `LIBRARY` | Admin | No | Manages its own content inside its library's academic scope |
| `ADMIN` | Admin / `createsuperuser` | No | Everything |

A single `role` field on the user (not Django groups) — roles are mutually exclusive and fixed by the
requirements, so a field is simpler, indexable, and easy to reason about in permission classes. Django's
`is_staff`/`is_superuser` are kept only for the internal Django admin site.

---

## 3. Ambiguities, gaps and conflicts found

| # | Requirement | Issue | Proposed resolution |
|---|---|---|---|
| 1 | FR-024/031/079 | Can a student see **all** universities' content, or only their own university/faculty? FR-024 implies browsing all; FR-031 says "content the student is *authorised* to see". | **[Q-1]** Default **[A-1]**: all active students see all *published* content in *active* catalog nodes. |
| 2 | FR-001/002 | Login identifier: email, student number, or both? Is student number unique globally or per university? | **[A-2]** Login with email **or** student number; student number unique **per university** → student has an optional `university` FK. |
| 3 | FR-001/005 | How does a newly created student get a password? | **[Q-5]** Default **[A-3]**: admin sets a temporary password, `must_change_password=True` forces change on first login. Email invitation added if SMTP is available. |
| 4 | FR-004 | "Verify identity before reset" — channel not specified. | **[A-4]** Email one-time link/code (Django `PasswordResetTokenGenerator`, single-use, time-limited). Requires SMTP. Admin can also reset a password manually. |
| 5 | FR-008/009 | A server cannot *prove* the identity of a mobile device; any device ID is ultimately client-supplied. | **[Q-4]** Default **[A-5]**: client generates a random 128-bit *installation ID* stored in Android Keystore / iOS Keychain; it is bound to every session server-side. Stronger option: hardware-backed key pair + signed requests / Play Integrity / App Attest (later phase). |
| 6 | FR-010/011 | A student on a *new* device has no valid session, yet must submit a change request **from** that device (so we learn its ID). | Login from an unbound device returns `403 device_not_bound` **plus a restricted, short-lived token** that can only create/read device-change requests. |
| 7 | FR-008 vs Library/Admin | Device binding only stated for students. | **[A-6]** Library/Admin are not device-bound. |
| 8 | — | May the same physical device be bound to two student accounts? | **[A-7]** Allowed (not required by any FR). Easy to add a constraint later. |
| 9 | FR-019 | Semesters: global, per faculty, or per level? | **[A-8]** Semesters are defined **per faculty** (e.g. "الفصل الأول/الثاني"), optional on courses and exam papers. |
| 10 | FR-020/021 | Course ↔ specialization cardinality. | **[A-9]** M2M; a course with no specialization is common to all specializations of its level. |
| 11 | FR-022 | Is an instructor global or per university? | **[A-10]** Instructor is a standalone entity (optional university), linked to courses via an ordered M2M. A lecture's instructor **must** be linked to its course (validated). |
| 12 | FR-021 | Course "linked to university, faculty, year". Storing all three invites inconsistency. | Course has a single FK to **Level**; university/faculty are derived (normalised). |
| 13 | FR-059/060/039/049 | Library scope granularity, and who may edit content when two libraries' scopes overlap. | **[Q-3]** Default **[A-11]**: scope = set of universities and/or faculties (and optionally courses). A library manages only content **it owns** *and* that is **inside its current scope**. |
| 14 | FR-040/049 | "Delete or archive". Hard deletes destroy audit history. | **[A-12]** Library: delete **drafts** only; published content can only be **archived**. Admin may hard-delete. Catalog nodes with content are protected (`on_delete=PROTECT`) — deactivate instead. |
| 15 | FR-054 | Word/other formats require server-side conversion (LibreOffice) → background worker infrastructure. | **[Q-2]** Default **[A-13]**: Phase 1 accepts **PDF + images (JPEG/PNG/WebP)** only; Word is rejected with a clear message. DOCX/PPTX→PDF conversion is a defined Phase 2 module. |
| 16 | FR-055/056/076 | Storage target and delivery mechanism unspecified. | **[Q-6]** Default **[A-14]**: private storage outside web root; files streamed only through an authorised endpoint (nginx `X-Accel-Redirect` in production; S3 private bucket + proxy as alternative). |
| 17 | FR-057 | Server-side watermarking of every PDF view is CPU-expensive. | **[A-15]** API returns a non-sensitive `watermark_text` (e.g. short student code + timestamp); the app overlays it. Server-side burn-in left as future option. |
| 18 | FR-058 | Screenshot blocking is purely client-side. | Out of backend scope; documented. |
| 19 | FR-066 | Review-before-publish is a client decision. | Implemented behind a system setting `require_content_review` (default **off**). |
| 20 | FR-070/071/072 | "Agreed channel" for notifications not defined. | **[Q-7]** Default **[A-16]**: in-app notifications stored in DB (pull). Push (FCM/APNs) designed as a pluggable channel, Phase 2. |
| 21 | FR-071 | "Courses they follow" — no follow feature defined. | Add `CourseFollow` (student opt-in). Notifications go only to followers. |
| 22 | FR-036 | "Classification" (التصنيف) of a lecture is undefined. | **[A-17]** A small admin-managed lookup `LectureCategory` (e.g. نظري/عملي/ملخص). |
| 23 | FR-047 | "Academic year or exam year". | **[A-18]** `exam_year` as an integer start-year (2024 ⇒ "2024/2025"), validated range. |
| 24 | — | Paid subscriptions / content purchase are not in the FRs. | Not implemented; noted as a likely future requirement (design does not block it). |
| 25 | Doc text | The "Functional Requirements" section of the brief repeats sections 12–14 of the engineering brief; FR-045's description is in plain text without the usual table. | Treated as duplicates; FR-045 read as "library uploads exam-paper files". |

---

## 4. Architecture

### 4.1 Style

A **modular monolith**: one Django project, one PostgreSQL database, domain-oriented Django apps. No
microservices, no message broker in Phase 1 — none of the FRs need them yet.

Layering inside each app (only where it pays off):

```
views (HTTP, permissions, serializers)  →  services (write use-cases, transactions, audit)
                                        →  selectors (read querysets: visibility, scope, prefetching)
models (schema, constraints, small invariants)
```

- **Services** exist for multi-step writes with business rules (login + device binding, device-change approval,
  publish workflow, file replacement, bulk upload). Simple CRUD stays in serializers/viewsets.
- **Selectors** centralise *visibility* rules (e.g. `visible_contents_for(user)`, `library_scoped_contents(library)`)
  so every endpoint — list, detail, search, file stream, favorites — uses the same rule. This is the main defence
  against IDOR.
- No repository layer: the Django ORM already is one.

### 4.2 Django apps

```
unilect/                     # project package: settings (base/dev/test/prod), urls, asgi/wsgi
apps/
  core/          # base model mixins, exception handler, error format, pagination, permissions, throttles, utils
  accounts/      # User, auth sessions, login/logout/refresh, password reset/change, profile, admin user mgmt
  devices/       # StudentDevice, DeviceChangeRequest, device-binding service & authentication check
  academics/     # University, Faculty, Level, Semester, Specialization, Course, Instructor, CourseInstructor
  libraries/     # Library, scope, library members
  content/       # ContentItem (lecture | exam paper), ContentFile versions, ExamType, LectureCategory,
                 # upload validation, protected file delivery, favorites, course follows, stats
  notifications/ # Notification model + service (in-app channel; push channel later)
  reports/       # ContentReport + ReportAction
  audit/         # AuditLog model + `audit.record(...)` service + secret-scrubbing
  config/        # SystemSettings (singleton) — upload limits, allowed types, review toggle
```

### 4.3 Key technical decisions

| Decision | Choice | Why |
|---|---|---|
| Framework | **Django 5.2 LTS** + **DRF 3.16** | LTS support to 2028; stable. |
| DB | **PostgreSQL 16+** (Docker for local dev) | Partial unique constraints, `pg_trgm` for Arabic-friendly substring search, robust row locking. |
| Auth | **djangorestframework-simplejwt** access/refresh tokens **+ server-side `AuthSession`** | FR-003/009/014 require *immediate* revocation and a device check per request. Each token carries a `sid` claim; a custom authentication class loads the session (1 indexed lookup) and rejects revoked sessions, inactive users, or device mismatch. Refresh tokens rotate; reuse of an old refresh token revokes the session (theft detection). Short access TTL (≈10 min). |
| Device check | Session ↔ device binding, plus `X-Device-ID` header must match | Token alone is not enough; a token copied to another device fails. |
| Docs | **drf-spectacular** (OpenAPI 3) + Swagger UI | Actively maintained; schema generated from code so docs match implementation. |
| Filtering | **django-filter** + DRF `SearchFilter`/`OrderingFilter` | Standard, declarative. |
| Search | `icontains` on title/description backed by **pg_trgm GIN** indexes | Postgres full-text has no Arabic stemmer; trigram works for Arabic and partial words. |
| File type check | **filetype** (magic bytes, pure Python) + **Pillow** verify for images + extension whitelist + size limit | Pure-Python works on Windows/Linux without libmagic. Never trust client MIME. |
| File storage | Django storage API, private root; `FileSystemStorage` (dev) / S3 via django-storages (optional prod) | Swappable without code changes. |
| File delivery | Authorised streaming endpoint, `Content-Disposition: inline`, `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`; prod uses nginx `X-Accel-Redirect` | No public or permanent URLs (FR-055/076); every access re-checks auth + device + visibility (FR-056). |
| Throttling | DRF scoped throttles (login, refresh, password reset, device-change request, file stream) | Brute-force & scraping protection. Redis cache in prod; locmem in dev/tests. |
| Config | **django-environ**, `.env` (never committed) | 12-factor; no secrets in code. |
| Background jobs | **None in Phase 1** (`transaction.on_commit` for email/notification fan-out) | No FR needs a broker yet; Celery+Redis introduced only with DOCX conversion or push notifications. |
| i18n | `LANGUAGE_CODE="ar"`, messages translatable; every error also has a stable English `code` | Arabic UI; clients branch on `code`, not text. |
| Tests | **pytest + pytest-django + factory-boy** against PostgreSQL | Same DB engine as prod so constraints are really tested. |
| Quality | **ruff** (lint + format), `manage.py check --deploy`, `makemigrations --check` | One fast tool. |
| API versioning | URL prefix `/api/v1/` | Mobile clients can't be force-upgraded; explicit versions are simplest to operate. |

---

## 5. Data model

```
User (custom, UUID pk)
  email (unique, ci), full_name, role, student_number, university→University (nullable, students),
  is_active, must_change_password, date_joined, ...
  UNIQUE(university, student_number) WHERE student_number IS NOT NULL
  library → Library (nullable; required iff role=LIBRARY, CHECK constraint)

AuthSession            id(UUID=sid), user, device→StudentDevice (nullable), refresh_jti, created_at,
                       last_used_at, expires_at, revoked_at, revoke_reason, ip, user_agent
StudentDevice          user, installation_id_hash, platform(android|ios), model, app_version,
                       status(active|revoked), bound_at, revoked_at
                       UNIQUE(user) WHERE status=active          ← FR-075 enforced by the DB
DeviceChangeRequest    student, current_device, new_installation_id_hash, new_platform/model, reason,
                       status(pending|approved|rejected|cancelled), decided_by, decided_at, decision_note
                       UNIQUE(student) WHERE status=pending      ← one open request per student

University             name, slug, is_active, sort_order
Faculty                university(PROTECT), name, is_active, sort_order   UNIQUE(university, name)
Level (السنة/المستوى)   faculty(PROTECT), name, number, is_active, sort_order UNIQUE(faculty, number)
Semester               faculty(PROTECT), name, number, sort_order          UNIQUE(faculty, number)
Specialization         faculty(PROTECT), name, is_active, sort_order
Course (المادة)         level(PROTECT), semester(nullable), specializations(M2M), name, code, is_active, sort_order
                       CHECK semester.faculty == level.faculty (service-level validation)
Instructor (الدكتور)    full_name, title, university(nullable), is_active
CourseInstructor       course, instructor, sort_order   UNIQUE(course, instructor)

Library                name, is_active, universities(M2M), faculties(M2M), courses(M2M)   ← scope
LectureCategory        name, is_active, sort_order        (admin-managed)
ExamType               name, is_active, sort_order        (admin-managed, FR-048)

ContentItem            kind(lecture|exam), status(draft|pending_review|published|archived),
                       library(PROTECT), course(PROTECT), instructor(nullable),
                       title, description, created_by, updated_by, published_at, archived_at,
                       -- lecture-specific: lecture_number, category→LectureCategory
                       -- exam-specific:    exam_year, semester→Semester, exam_type→ExamType
                       CHECK: published ⇒ kind-specific required fields present   ← FR-078
                       INDEX (status, course), (library, status), trigram(title), trigram(description)
ContentFile            content, version, storage_key, original_name, extension, mime_type,
                       size_bytes, sha256, page_count(nullable), uploaded_by, uploaded_at, is_current
                       UNIQUE(content) WHERE is_current         ← exactly one live file (FR-041)
                       UNIQUE(content, version)

Favorite               student, content    UNIQUE(student, content)
CourseFollow           student, course, notify_new_content     UNIQUE(student, course)
Notification           recipient, type, title, body, data(JSON), read_at, created_at
                       INDEX (recipient, read_at, created_at)
ContentReport          content, reporter, reason(wrong|duplicate|inappropriate|other), message,
                       status(open|in_review|resolved|rejected), handled_by
                       UNIQUE(content, reporter) WHERE status in (open, in_review)
ReportAction           report, actor, from_status, to_status, note, created_at
AuditLog               actor(nullable), action, category(account|device|content|catalog|security|settings),
                       target_type, target_id, target_repr, metadata(JSON, scrubbed), ip, created_at
                       INDEX (category, created_at), (target_type, target_id)
SystemSettings         singleton: max_upload_mb, allowed_extensions, require_content_review,
                       restricted_token_ttl, ... (validated against a hard server-side whitelist)
```

**Why one `ContentItem` table for lectures *and* exam papers?** Search (FR-031), filtering (FR-032),
favorites (FR-034), library dashboard (FR-061/062), admin management (FR-065), review (FR-066),
reports (FR-073), notifications (FR-071) and protected delivery (FR-056) all operate on "content"
regardless of kind. A single table with a `kind` discriminator and DB check constraints for kind-specific
fields avoids generic foreign keys and `UNION` queries. The kind-specific columns are few (5), so sparsity
is negligible.

**Visibility rule (single selector, used everywhere for students):**
`status=published AND course.is_active AND level.is_active AND faculty.is_active AND university.is_active`
(+ the student's university/faculty filter if [Q-1] says so).

---

## 6. Critical workflows

### 6.1 Login + first-device binding (FR-002, 008, 009, 010, 075)

```
POST /api/v1/auth/login {identifier, password, device:{installation_id, platform, model, app_version}}
  1. throttle (per IP and per identifier)
  2. authenticate; inactive → same generic "invalid credentials" (no user enumeration)
  3. if role != STUDENT → create AuthSession(device=None) → tokens
  4. STUDENT, in a transaction with SELECT … FOR UPDATE on the user row:
       a. no active device       → bind this one (StudentDevice active), audit "device.bound"
       b. active device matches  → ok
       c. different device       → 403 {code:"device_not_bound", message:…, how_to_request:…,
                                         device_change_token:<restricted, 15 min>}
                                    audit "security.login_unbound_device"
  5. create AuthSession(device) → access + refresh (both carry sid)
```
The partial unique index guarantees that two simultaneous "first" logins from two phones cannot both bind.

### 6.2 Every protected request (FR-009, 014, 077)
Custom `SessionJWTAuthentication`: valid signature/expiry → load `AuthSession` by `sid` (select_related user,
device) → reject if revoked/expired, user inactive, or (student) device not active or `X-Device-ID` hash ≠ bound
device. Then permission classes (role) → selector (visibility/scope) → object permission.

### 6.3 Device change (FR-011…015, 067, 070)
```
student (restricted token) → POST /me/device-change-requests {reason?}  → status=pending, admin sees it
admin → POST /admin/device-change-requests/{id}/approve  (transaction, row locks):
           revoke old StudentDevice → revoke ALL AuthSessions of the student
           → create new active StudentDevice from the request → request.approved (by, at)
           → AuditLog + Notification ("approved")
admin → …/reject {note} → request.rejected (by, at, note) → AuditLog + Notification
```
Admin can also directly *reset* a student's device (lost phone) — same service, audited.

### 6.4 Content lifecycle (FR-035…044, 049, 066, 078, 079)
```
draft ──submit──► (require_review? pending_review : published)
pending_review ──admin approve──► published   | ──admin reject (note)──► draft
published ──archive──► archived ──restore──► draft/published
draft ──delete──► (gone, file deleted on commit)
```
Required-field validation is enforced by the service on submit **and** by DB check constraint on published rows.
Preview (FR-044) = library/admin fetching a draft's metadata and file through the same protected endpoint
(authorised by scope instead of by "published").

### 6.5 Upload & validation (FR-035, 043, 063, 069)
Size check (streamed, before reading fully) → extension whitelist ∩ SystemSettings → magic-byte detection must
agree with extension → Pillow `verify()` for images / PDF header + basic parse for PDFs → SHA-256 → saved under a
random UUID storage key (original filename kept only as metadata). Bulk upload processes each item in its own
savepoint and returns a per-item result list.

---

## 7. API surface (v1)

Response envelope for errors: `{"error": {"code": "...", "message": "...", "details": {...}}}`.
Lists: page-number pagination `{count, next, previous, results}`, max page size enforced.

| Area | Endpoints | Who |
|---|---|---|
| Auth | `POST auth/login`, `auth/refresh`, `auth/logout`, `auth/password/reset`, `auth/password/reset/confirm`, `auth/password/change` | Public / authenticated |
| Profile | `GET/PATCH me` (only `full_name`, `phone`… writable) | All |
| Device (student) | `GET me/device`, `GET/POST me/device-change-requests`, `POST …/{id}/cancel` | Student (restricted token allowed) |
| Catalog (read) | `GET catalog/universities`, `catalog/faculties?university=`, `catalog/levels?faculty=`, `catalog/semesters?faculty=`, `catalog/specializations?faculty=`, `catalog/courses?level=&specialization=&semester=`, `catalog/courses/{id}/instructors`, `catalog/exam-types`, `catalog/lecture-categories` | Authenticated |
| Content (student) | `GET catalog/contents?kind=&university=&faculty=&level=&course=&instructor=&semester=&exam_year=&exam_type=&category=&search=&ordering=`, `GET catalog/contents/{id}`, `GET catalog/contents/{id}/file`, `POST catalog/contents/{id}/reports` | Student (published only) |
| Favorites / follows | `GET/POST/DELETE me/favorites`, `GET/POST/PATCH/DELETE me/followed-courses` | Student |
| Notifications | `GET me/notifications`, `POST me/notifications/{id}/read`, `POST me/notifications/read-all` | All |
| Library content | `GET/POST manage/contents`, `GET/PATCH/DELETE manage/contents/{id}`, `POST …/{id}/file` (replace), `GET …/{id}/versions`, `POST …/{id}/submit|archive|restore`, `GET …/{id}/file` (preview), `POST manage/contents/bulk`, `GET manage/stats` | Library (scoped) & Admin |
| Admin – accounts | `admin/users` CRUD + `…/{id}/deactivate|activate|reset-device|revoke-sessions|set-password` | Admin |
| Admin – catalog | `admin/universities|faculties|levels|semesters|specializations|courses|instructors|course-instructors` CRUD (+ `sort_order`) | Admin |
| Admin – libraries | `admin/libraries` CRUD incl. scope | Admin |
| Admin – content | `admin/contents` (all content), `…/{id}/approve|reject|archive|hide` | Admin |
| Admin – devices | `admin/device-change-requests?status=&ordering=created_at`, `…/{id}/approve|reject` | Admin |
| Admin – misc | `admin/dashboard`, `admin/audit-logs?category=&actor=&target=`, `admin/reports` + `…/{id}/transition`, `admin/exam-types`, `admin/lecture-categories`, `GET/PATCH admin/settings` | Admin |
| Docs | `api/schema/`, `api/docs/` (Swagger) | Admin-only in production |

---

## 8. Security design (summary)

- Server-side authorization on every endpoint: default permission `IsAuthenticated` + role class + scoped
  selector; object retrieval always goes through the scoped queryset (404 on out-of-scope, not 403, to avoid
  existence leaks).
- Protected fields (role, email, student_number, is_active, university, library) are read-only in the profile
  serializer; unknown/forbidden fields in PATCH are **rejected** with 400 (FR-007), not silently ignored.
- Generic login error; per-IP and per-identifier throttles; password validators; Argon2/PBKDF2 hashing.
- Installation IDs stored as **HMAC-SHA256 hashes**, never in plaintext; never logged.
- Audit metadata passes through a scrubber (`password`, `token`, `secret`, `authorization`, … keys removed) (FR-080).
- Production settings: `DEBUG=False`, `SECURE_SSL_REDIRECT`, HSTS, secure cookies, `ALLOWED_HOSTS`/
  `CSRF_TRUSTED_ORIGINS`/`CORS_ALLOWED_ORIGINS` from env; `check --deploy` clean.
- Uploaded files: never executed, never served from `MEDIA_URL`, random storage names, `nosniff`.
- Logging: structured JSON in prod; security events (failed logins, unbound-device attempts, permission denials
  on file access, refresh-token reuse) logged at WARNING with request id, without secrets.

## 9. Performance notes

- Student list endpoints: `select_related(course__level__faculty__university, instructor, exam_type, …)` and
  `annotate(is_favorite=Exists(...))` → constant query count per page (asserted with `django_assert_num_queries`).
- Composite indexes for the main filter paths; trigram indexes for search.
- Auth session lookup is one PK query per request; can be cached in Redis later if measured as a bottleneck.
- Notification fan-out to followers via `bulk_create` in `on_commit`; move to a worker if follower counts grow.

---

## 10. Requirements traceability (planned)

| FR | Component(s) | Key tests |
|---|---|---|
| 001 | accounts: admin user create service/serializer | unique email/student number; role required |
| 002 | accounts: login service, `SessionJWTAuthentication` | good/bad creds, inactive user, generic error |
| 003 | `auth/logout` revokes AuthSession | token rejected after logout |
| 004 | password reset request/confirm | single-use, expiry, no user enumeration |
| 005 | `admin/users` + activate/deactivate | deactivated user's existing tokens rejected |
| 006 | `role` field, permission classes | each role blocked from others' endpoints |
| 007 | `PATCH me` | protected fields rejected |
| 008 | devices: bind-on-first-login | first login binds; concurrent first logins |
| 009 | auth class device check | token reused with other `X-Device-ID` rejected |
| 010 | login → `device_not_bound` + restricted token | restricted token can't access content |
| 011 | `me/device-change-requests` | one pending at a time |
| 012 | approve/reject service | decided_by/at recorded; notification created |
| 013 | approve service | old device rejected afterwards |
| 014 | revoke all sessions on approval | old access & refresh tokens rejected |
| 015 | AuditLog (category=device) | entries for bind/request/approve/reject/reset |
| 016–023 | academics: admin CRUD + `sort_order` | FK integrity, PROTECT, ordering |
| 024–028 | catalog read endpoints + filters | inactive nodes hidden; parent filter correct |
| 029–030, 033 | catalog/contents list/detail | only published; metadata fields |
| 031–032, 050 | content filters + search | each filter; search respects visibility |
| 034 | favorites | persists; can't favorite invisible content |
| 035–038, 043 | manage/contents create + upload validation | bad ext/MIME/size rejected with reason |
| 039–040, 049 | scoped update/delete/archive | out-of-scope → 404; archived hidden |
| 041 | file replace → new ContentFile version | student gets current version |
| 042, 066, 078–079 | publish workflow service + DB constraints | illegal transitions; review toggle |
| 044 | preview via manage file endpoint | library sees own draft; student can't |
| 045–048 | exam papers (kind=exam), ExamType | exam-specific required fields |
| 051–054 | file endpoint (PDF/images); unsupported → clear error | content-type & headers |
| 055–056, 076 | protected stream; private storage | no public URL; device/visibility checked |
| 057 | `watermark_text` in file/detail response | contains no PII |
| 058 | client-side; documented | — |
| 059–062 | libraries + scope selector + stats | scope limits lists and writes |
| 063 | bulk upload | per-item success/failure |
| 064–065 | admin dashboard + admin content | counts match data |
| 067 | admin device requests list | filter by status, order by date |
| 068, 080 | AuditLog + scrubber + security logging | no secrets in logs |
| 069 | SystemSettings | new limits apply to next upload |
| 070–072 | notifications | delivered to right recipients only |
| 073–074 | reports + actions | status history saved |
| 075 | partial unique index + locking | second active device impossible |
| 077 | permission tests calling APIs directly | — |

---

## 11. Implementation plan (incremental, each step verified)

1. Project skeleton, settings split, env config, Docker Compose (Postgres), ruff, pytest, error handler, health check.
2. `accounts` + `devices` + `audit`: user model, sessions, login/refresh/logout, device binding, change requests. **Tests.**
3. `academics`: models, admin CRUD, catalog read endpoints. **Tests.**
4. `libraries` + `config`: scope model and selectors, system settings. **Tests.**
5. `content`: models, upload validation, workflow services, manage endpoints, student endpoints, protected
   delivery, favorites/follows. **Tests (incl. query-count tests).**
6. `notifications`, `reports`, dashboards/stats. **Tests.**
7. Security review (`check --deploy`, permission matrix tests), OpenAPI schema validation, README,
   traceability matrix finalised, known limitations.
