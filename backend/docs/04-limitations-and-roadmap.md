# Known Limitations, Assumptions in Force, and Roadmap

Nothing here is a hidden defect. Each item is a deliberate scope decision or a limit of what a backend can enforce.

## 1. Assumptions in force (approved defaults)

| Id | Assumption | Where to change |
|---|---|---|
| A-1 | Every active student can see **all** published content in active academic paths, not only their own university. | `content.selectors.visible_contents` |
| A-2 | Login uses the email, **or** the student number plus university. Student numbers are unique per university. | `accounts.serializers.LoginSerializer` |
| A-3 | Admin-created accounts get a temporary password and must change it at first login. | `AdminUserSerializer.must_change_password` default |
| A-5 | A device is identified by a client-generated installation id (stored as an HMAC hash). | `devices.utils` |
| A-6 | Only students are device-bound. | `SessionJWTAuthentication` |
| A-7 | One physical device may be bound to several student accounts. | Add a constraint on `installation_id_hash` |
| A-8 | Semesters are defined per faculty. | `academics.Semester` |
| A-11 | A library manages only content it owns, and only while that content is inside its scope. | `content.selectors.manageable_contents` |
| A-12 | Libraries delete drafts only. Published content is archived. Admins may hard-delete. | `content.services.delete` |
| A-13 | Accepted formats are **PDF and images** (jpg, jpeg, png, webp). Office files are rejected with a clear message. | `CONTENT_SUPPORTED_EXTENSIONS` |
| A-15 | The watermark is drawn by the app using the server-provided `watermark_text`. | `content.delivery` |
| A-16 | Notifications are in-app only (pull). | `notifications.services` |
| A-17 | Lecture "classification" is an admin-managed `LectureCategory` list. | `admin/lecture-categories/` |
| A-18 | `exam_year` is the starting year of the academic year (2024 = 2024/2025). | — |

### Policies decided during hardening

| Policy | Behaviour |
|---|---|
| Deactivated instructor | Their content is hidden from students, consistent with the browse path no longer listing them. |
| Deactivated category or exam type | Blocks new use only. Existing content stays visible. |
| Library edits to published content while review is on | The item goes back to `pending_review` and is hidden until approved. Admin edits apply immediately. |
| Role change away from student | Device binding released, pending device request cancelled, sessions revoked. |
| Session lifetime | Sliding 30 days, hard cap 90 days after login (`SESSION_MAX_DAYS`). |
| Retention (`purge_expired`) | Ended sessions after 30 days, read notifications after 180 days, file history keeps 5 old versions, audit kept forever (configurable). |

## 2. Resolved in the hardening pass

| Former issue | Resolution | Proof |
|---|---|---|
| Possible deadlock between approve and reset | Every device operation locks the student row first | `test_concurrency.py`. With the old order put back, the test reproduces PostgreSQL `deadlock detected`. |
| Arabic search ignored letter variants | `core.text.normalize` + normalised `search_document` column | `test_search.py` (Python and SQL normalisers checked against each other) |
| Search unindexable across joins | One trigram-indexed column; the query is asserted to use it | `test_search_uses_single_indexed_column` |
| Sessions could live forever; tables grew forever | `SESSION_MAX_DAYS` + `purge_expired` command | `test_policies.py::TestSessionLifetime`, `TestRetention` |
| Extra queries in classification | Raw column access without loading related objects | `test_classification_validation_query_budget` |
| Per-process cache and stale settings | Redis supported and required (`unilect.W001`); invalidation both immediately and on commit | `TestDeployChecks`, stack run |
| Account lockout usable to lock others out | Two-tier lockout (per IP, plus a high per-account ceiling) | `TestLoginLockoutTiers` |
| Unbounded PDF parsing | 3000-page cap | `test_pdf_page_cap` |
| Reverse dependencies (`core` → accounts, `content` → reports) | Permissions moved to accounts; `dashboard` and `maintenance` apps | Import graph |
| English-only own messages | Arabic catalogue (100% translated); notifications use the site language | `TestArabicLocalisation` |
| Docker, nginx, SMTP never run | Production-like stack verified (33/33 checks) | README "Last verified run" |
| Possible orphan file if the DB write fails | File removed when the row write fails | `test_no_orphan_file_when_row_write_fails` |

## 3. Known limitations (remaining)

1. **Device identity can't be proven by a server.** The installation id is a bearer secret kept in Keystore/Keychain.
   A rooted or jailbroken device could extract and clone it. The server enforces everything it can; stronger binding
   needs client work (roadmap item 1).
2. **Content can't be made un-copyable.** Inline-only delivery, no public links, `no-store`, watermark data and
   throttling deter casual copying. They don't stop screen recording or photographing the screen. Screenshot blocking
   (FR-058) is a client feature and isn't guaranteed on every device.
3. **Word and other Office formats (FR-054)** aren't converted. They're rejected with a message asking for a PDF.
4. **Uploads are parsed synchronously during the request** (bounded by size, page and pixel caps). Very large PDFs
   make that request slow. Move parsing to a worker if libraries upload such files often.
5. **Upload size is checked after the body is received.** nginx `client_max_body_size` (configured in
   `deploy/`) rejects oversized bodies early.
6. **Notification fan-out runs synchronously** after commit (`bulk_create`, batches of 1000). That's fine for
   thousands of followers; move it to a worker for very large audiences.
7. **Search is substring matching, not linguistic.** There's no stemming or root extraction (e.g. «كتب» won't match
   «مكتبة» unless the substring is present) and no relevance ranking; results use the normal ordering.
8. **The audit log is append-only by convention.** There's no API to edit or delete it, but database administrators
   can. Ship it to tamper-evident storage for compliance (roadmap item 7).
9. **The "account disabled" message** is shown after a correct password. That's a deliberate usability trade-off: it
   only confirms an account's existence to someone who already knows its password.
10. **CI hasn't run on GitHub** because there's no remote yet. The workflow mirrors commands that were all run locally.
11. **No load test has been run.** Query counts are bounded and asserted, and indexes are in place, but throughput
    under real load is unmeasured.
12. **The Django admin site** (`/django-admin/`) is only for superusers and doesn't register the domain models.
    Administration goes through the API.

## 4. Roadmap / future improvements

1. **Hardware-backed device binding:** a key pair in Android Keystore / iOS Secure Enclave, plus Play Integrity /
   App Attest attestation at binding time and request signing.
2. **DOCX/PPTX → PDF conversion** with a LibreOffice headless worker (Celery + Redis).
3. **Push notifications** (FCM/APNs) as an extra channel, with per-user preferences.
4. **Server-side watermark burn-in** for PDFs, if the client overlay isn't enough.
5. **Background upload processing** (parsing, page counting, thumbnails) for very large files.
6. **Student CSV bulk import** for admins.
7. **External tamper-evident audit sink** (append-only object storage or SIEM).
8. **2FA for admin accounts.**
9. **Load testing** (e.g. Locust) against the production-like stack, to set worker counts and cache TTLs from data.
10. **Arabic root-aware search ranking** (e.g. a dedicated search engine) if substring matching proves insufficient.
