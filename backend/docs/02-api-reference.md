# UniLect API v1 — Reference

The full machine-readable contract is [api/openapi.yaml](api/openapi.yaml). It's generated from the code and
validated with `--fail-on-warn`, and also served live at `/api/v1/docs/`. This page summarises behaviour, permissions
and validation rules that a schema alone doesn't express.

## Conventions

- Base path `/api/v1/`. JSON request and response bodies; uploads use `multipart/form-data`.
- **Authentication:** `Authorization: Bearer <access>`. **Students** must also send `X-Device-ID: <installation id>`
  on every request, including `auth/refresh/`.
- **Pagination:** `?page=N&page_size=M` (default 20, max 100) → `{count, next, previous, results}`.
- **Search:** `?search=…`. Every whitespace-separated term must match (AND, max 8 terms). Matching ignores case,
  Arabic letter variants (أ/إ/آ/ٱ→ا, ة→ه, ى→ي, ؤ→و, ئ→ي), diacritics and tatweel, and treats Arabic-Indic digits
  as ASCII digits. So `احمد` finds «أحمد».
- **Ordering:** `?ordering=field` / `-field` where noted.
- **Language:** messages follow `Accept-Language` (`ar` default, `en`). `error.code` never changes with the language.
  Stored notifications always use the site language.
- **IDs:** catalog entities use integers; users, sessions, content, files, requests and reports use UUIDs.
- **Out-of-scope objects return `404`, not `403`**, so it doesn't leak whether a resource exists.
- **Errors:** every error has the same envelope. Clients must branch on `code`:

```json
{"error": {"code": "device_not_bound", "message": "…localised text…", "details": {}}}
```

| HTTP | Common `code` values |
|---|---|
| 400 | `validation_error` (`details.fields`), `file_rejected` (`details.reason`), `incomplete_content`, `invalid_current_password`, `invalid_reset_token`, `device_info_required`, `cannot_deactivate_self`, `not_a_student` |
| 401 | `not_authenticated`, `token_not_valid`, `session_revoked`, `account_disabled` (existing session), `invalid_credentials` |
| 403 | `permission_denied`, `device_mismatch`, `device_not_bound`, `account_disabled` (login), `password_change_required`, `library_only` |
| 404 | `not_found` |
| 405 | `method_not_allowed` |
| 409 | `invalid_transition`, `protected`, `request_already_pending`, `device_already_bound`, `no_device_bound`, `report_already_open` |
| 429 | `throttled` (`details.retry_after_seconds`), `too_many_failed_attempts` |
| 500 | `server_error` (no internals exposed) |

Role shorthand: **S** student · **L** library staff (whose library is active) · **A** admin · **Public** no auth.

---

## 1. Authentication & session (`/auth/`)

| Method & path | Who | Behaviour / validation |
|---|---|---|
| `POST auth/login/` | Public · 20/min/IP | Body: `email` **or** (`student_number` + `university`), plus `password`. Students must also send `device: {installation_id (16–128 chars, [A-Za-z0-9_-]), platform: android\|ios, model?, app_version?}`. **200** → `{access, refresh, token_type, access_expires_in, refresh_expires_in, user}`. A wrong password and an unknown account return the same **401** `invalid_credentials`. **403** `account_disabled` is only returned after a correct password. **403** `device_not_bound` means another device is bound; `details` has `device_change_token` (15 min), `device_change_token_expires_in` and `pending_request`. Failed attempts are limited in two tiers within a 15-minute window: 10 per (identifier, client IP), so an
attacker's IP is blocked while the real user can still sign in from elsewhere; and 100 per identifier from any IP,
which stops distributed guessing (**429** `too_many_failed_attempts`). |
| `POST auth/refresh/` | Public · 60/min/IP | `{refresh}` → a new pair. Refresh tokens rotate: replaying an old one **revokes the whole session** (theft detection). Students: `X-Device-ID` must match the bound device. Each refresh extends the session, but never beyond `SESSION_MAX_DAYS` (default 90) after login. |
| `POST auth/logout/` | Any authenticated | Ends the current session. Its access and refresh tokens stop working immediately. **204** |
| `POST auth/password/change/` | Any authenticated | `{current_password, new_password}`. The new password must pass Django's validators (min 10 chars, not common, not numeric, not similar to the user's details). Clears `must_change_password` and revokes the user's other sessions. **204** |
| `POST auth/password/reset/` | Public · 5/h/IP | `{email}` → always **202**. Emails a one-time link (`PASSWORD_RESET_URL_TEMPLATE`) valid for 1 h. |
| `POST auth/password/reset/confirm/` | Public · 5/h/IP | `{uid, token, new_password}`. The token is single-use (it's invalidated by the password change) and all sessions are revoked. **204** / **400** `invalid_reset_token` |

**`must_change_password`:** while it's set (the default for admin-created accounts), only `GET/PATCH me/`,
`auth/password/change/` and `auth/logout/` are allowed. Everything else returns **403** `password_change_required`.

## 2. Device binding (FR-008…015)

| Method & path | Who | Behaviour |
|---|---|---|
| `GET me/device/` | S | The active bound device (no identifiers exposed). |
| `GET me/device-change-requests/` | S | The student's own requests. |
| `POST auth/device-change-requests/` | S with **restricted token** · 10/h | Sent from the *new* device: `Authorization: Bearer <device_change_token>` + `X-Device-ID` of that device. Body `{reason?}` (≤ 1000). **201** `pending`. **409** `request_already_pending` / `device_already_bound` / `no_device_bound`. |
| `GET auth/device-change-requests/[{id}/]` | S (restricted) | Status polling from the new device. |
| `POST auth/device-change-requests/{id}/cancel/` | S (restricted) | Pending → cancelled. |
| `GET admin/device-change-requests/` | A | Filters `status`, `student`; `search` (email, name, student number); `ordering` `created_at`, `decided_at`, `status`. |
| `POST admin/device-change-requests/{id}/approve/` | A | `{note?}`. In one transaction: revoke the old device, revoke **all** sessions, bind the new device, record decider and time, audit, notify the student. **409** if already decided. |
| `POST admin/device-change-requests/{id}/reject/` | A | `{note?}`. Records the decision and notifies the student. |
| `POST admin/users/{id}/reset-device/` | A | Unbinds (e.g. lost phone): revokes the device and sessions and cancels pending requests. The next login binds a new device. |
| `GET admin/users/{id}/devices/` | A | Device history. |

The restricted token is rejected everywhere else, and is only accepted from the device it was issued to.
An access token is not accepted on `auth/device-change-requests/`.

## 3. Profile & notifications

| Method & path | Who | Behaviour |
|---|---|---|
| `GET me/` | Any | The user's own profile. |
| `PATCH me/` | Any | Writable fields: students `phone`; library/admin `full_name`, `phone`. **Any other field → 400** with that field listed (it is not silently ignored). |
| `GET me/notifications/` | Any | The user's own notifications only. Filters `unread=true\|false`, `type`. |
| `GET me/notifications/unread-count/` · `POST …/{id}/read/` · `POST …/read-all/` | Any | — |
| `GET config/` | Any | Settings the apps need before acting: `{max_upload_size_mb, allowed_extensions, require_content_review}` (read-only view of `admin/settings/`). |

## 4. Catalog browsing (read-only, any authenticated role)

Only **active** nodes whose ancestors are all active are listed (FR-024…028). Default order is `sort_order`, then name.

`in_scope=true` on `universities`, `faculties`, `levels` and `courses`: for **library staff**, only the nodes that contain
at least one course inside the library's scope (used by the upload pickers). Other roles ignore it. Writes still validate
scope.

| Path | Filters |
|---|---|
| `catalog/universities/` | `search` |
| `catalog/faculties/` | `university`, `search` |
| `catalog/levels/` | `faculty` |
| `catalog/semesters/` | `faculty` |
| `catalog/specializations/` | `faculty` |
| `catalog/courses/` | `university`, `faculty`, `level`, `semester`, `specialization` (also includes courses common to all specializations), `search`. Each course also carries its `faculty` and `university` ids. |
| `catalog/courses/{id}/instructors/` | Active instructors linked to the course, in the admin-defined order |
| `catalog/lecture-categories/`, `catalog/exam-types/` | Active lookups (not paginated) |

## 5. Content for students (FR-029…034, 050…057)

| Method & path | Who | Behaviour |
|---|---|---|
| `GET catalog/contents/` | Any | **Published content in an active academic path only**, and not belonging to a deactivated instructor. Deactivating a category or exam type only blocks new use; it never hides existing content. Filters `kind` (lecture\|exam), `university`, `faculty`, `level`, `course`, `instructor`, `semester` (an exam's own semester, or a lecture's course semester), `exam_year`, `exam_year_min`, `exam_year_max`, `exam_type`, `category`. `search` matches title, description, course name/code and instructor name, using a pre-normalised, trigram-indexed column. `ordering`: `published_at`, `title`, `lecture_number`, `exam_year`, `created_at`. Default: lecture number, then newest. |
| `GET catalog/contents/{id}/` | Any | Metadata shown before opening: title, description, the full academic path, instructor, category or exam info, `published_at`, file info (type, size, page count), `file_endpoint`, `is_favorite`, `watermark_text`. No storage paths or URLs. |
| `GET catalog/contents/{id}/file/` | Any · 300/h | Streams the **current** file with `Content-Disposition: inline`, `Cache-Control: no-store`, `nosniff` and `X-Watermark-Text`. Identity, device and visibility are re-checked on every call. In production nginx delivers the file via `X-Accel-Redirect`. |
| `POST catalog/contents/{id}/reports/` | S | `{reason: wrong\|duplicate\|inappropriate\|other, message?}`. One open report per student per item (**409** otherwise). |
| `GET/POST me/favorites/` · `DELETE me/favorites/{content_id}/` | S | Only visible content can be added (**400** otherwise). POST is idempotent (**201** create / **200** existing). Items that later become invisible drop out of the list. |
| `GET/POST me/followed-courses/` · `PATCH/DELETE me/followed-courses/{id}/` | S | `{course, notify_new_content}`. On a content item's **first** publication, followers who opted in get an in-app notification. |

## 6. Content management (library & admin) — `/manage/`

Library staff see and modify **only content owned by their library that lies inside the library's current scope**.
Admins see everything. Students get **403**.

| Method & path | Who | Behaviour / validation |
|---|---|---|
| `GET manage/contents/` | L, A | Filters as in §5, plus `status`, `library`. Search and ordering as in §5, plus `updated_at` and `status`. |
| `POST manage/contents/` | **L only** | Multipart. `kind`, `title`, `course` are required; `description`; optional `file`. **Lecture:** `instructor`, `category`, `lecture_number`. **Exam:** `instructor?`, `exam_year` (1950–2100), `exam_type`, `semester`. Rules: the course must be in the library's scope; the instructor must be linked to the course; the semester must belong to the course's faculty; lookups must be active; fields for the other kind are rejected. Created as `draft`. |
| `GET manage/contents/{id}/` | L, A | Includes `status`, `review_note` and current file metadata (`original_name`, `sha256`, version). |
| `PATCH manage/contents/{id}/` | L, A | Same rules. `kind` is immutable. Published items must stay complete (**400** otherwise). Replace the file through `/file/`. **When review is required**, a library change to a *published* item sends it back to `pending_review`, and it's hidden until approved. Admin edits apply immediately. |
| `DELETE manage/contents/{id}/` | L (draft only), A (any) | Published content is archived, not deleted (**409** for library staff). |
| `GET manage/contents/{id}/file/` | L, A | Preview the current file, including for drafts (FR-044). |
| `POST manage/contents/{id}/file/` | L, A | Upload a new version. It becomes current immediately and old versions are kept (**409** if archived). The same review rule as PATCH applies. `purge_expired` keeps the current version plus the newest `RETAIN_OLD_FILE_VERSIONS` older ones. |
| `GET manage/contents/{id}/versions/` | L, A | Version history. |
| `POST manage/contents/{id}/submit/` | L, A | `draft` → `published`, or → `pending_review` when `require_content_review` is on and the caller is a library. Requires all mandatory fields **and** a file (**400** `incomplete_content`, with the missing fields). |
| `POST manage/contents/{id}/approve/` | **A** | `pending_review` → `published`. Notifies the uploader. |
| `POST manage/contents/{id}/reject/` | **A** | `{note?}`. `pending_review` → `draft` with `review_note`. Notifies the uploader. |
| `POST manage/contents/{id}/archive/` | L, A | `draft`, `pending_review` or `published` → `archived`. Hidden from students immediately. |
| `POST manage/contents/{id}/restore/` | L, A | `archived` → `draft`. |
| `POST manage/contents/bulk/` | **L only** | Multipart: `items` is a JSON array (max 20) of create payloads, each with a `file_field` naming the multipart part that holds its file. Each item is processed independently → `{results: [{index, ok, id?, error?}]}`. |
| `GET manage/stats/` | L, A | `{total, by_status, by_kind}` within the caller's scope. |

Invalid workflow transitions return **409** `invalid_transition` with `details.status`.

### Upload validation (FR-043, FR-069)

Checks run in this order. A failure returns **400** `file_rejected` with `details.reason`, and nothing is stored:

| reason | Rule |
|---|---|
| `unsupported_format` | Office formats (doc/docx/ppt/…). The message asks for a PDF instead. |
| `extension_not_allowed` | Extension not in (admin `allowed_extensions` ∩ server whitelist `pdf, jpg, jpeg, png, webp`). `details.allowed_extensions` lists what's allowed. |
| `empty_file` / `file_too_large` | Size must be between 1 byte and `max_upload_size_mb` (admin-set, hard cap 200 MB). |
| `content_mismatch` | Magic bytes don't match the extension (the client's Content-Type is never trusted). |
| `corrupt_file` / `encrypted_pdf` / `too_many_pages` / `image_too_large` | PDF must parse, have between 1 and 3000 pages, and no password. Images must pass Pillow verification and be ≤ 60 MP. |

Stored files get a random name in private storage; the original name is kept only as metadata.

## 7. Administration — `/admin/` (admin only)

| Path | Notes |
|---|---|
| `admin/users/` (GET, POST, GET/PUT/PATCH `{id}`) | Filters `role`, `is_active`, `university`, `library`; `search` (email, name, student number). Responses include `university_name` and `library_name`. Create requires `password`; `must_change_password` defaults to true. Students need `student_number` + `university` (the number is unique per university). Library staff need `library`. Fields that don't apply to the role are cleared. Email is unique (case-insensitive). Changing role, email, library or university revokes the user's sessions. An admin can't change their own role or deactivate themselves. **No DELETE**: deactivate instead. |
| `admin/users/{id}/activate/`, `/deactivate/`, `/set-password/` (`{password, must_change_password}`), `/revoke-sessions/`, `/reset-device/`, `/devices/` | Deactivating or setting a password revokes all sessions. |
| `admin/universities\|faculties\|levels\|semesters\|specializations\|instructors\|courses\|course-instructors/` | Full CRUD with `is_active`, `sort_order` and parent filters. Deleting a node that still has children or content returns **409** `protected`: deactivate it instead. A course's semester and specializations must belong to its faculty. An instructor linked to a course must belong to the same university (if one is set), and can only be linked once. |
| `admin/libraries/` | CRUD with scope `scope_universities`, `scope_faculties`, `scope_courses` (union). A library with staff can't be deleted (**409**). |
| `admin/lecture-categories/`, `admin/exam-types/` | Manageable lookups (FR-048). |
| `admin/settings/` (GET, PATCH) | `max_upload_size_mb` (1…200), `allowed_extensions` (subset of the whitelist), `require_content_review`, `notify_followers_on_publish`. Applies to subsequent operations. Audited. |
| `admin/dashboard/` | Accounts by role and inactive count; content by status and kind; pending device requests, content waiting for review, open reports. |
| `admin/reports/` (+ `{id}/transition/` `{status, note?}`, `{id}/notes/` `{note}`) | Allowed transitions: open → in_review, resolved or rejected; in_review → resolved or rejected. Each change or note is kept in `actions`. The reporter is notified when a report is resolved or rejected. |
| `admin/audit-logs/` | Read-only. Filters `category` (account, auth, device, catalog, library, content, report, settings, security), `action`, `action_prefix`, `actor`, `target_type`, `target_id`, `created_after`, `created_before`. Device history is `?category=device`; device entries carry the student's email in `metadata.student`. |

## 8. Rate limits (defaults, `REST_FRAMEWORK.DEFAULT_THROTTLE_RATES`)

anon 120/min · user 600/min · login 20/min per IP plus failed-login tiers (10 per identifier+IP, 100 per identifier, 15 min) · refresh 60/min ·
password reset 5/h · device-change request 10/h · file viewing 300/h per user.
