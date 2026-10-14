# UniLect — Requirements Analysis, Feature Mapping & Implementation Plan

> Status legend: ✅ implemented in app · 🟡 enforced by the backend (the app handles the outcome; verified end-to-end by `test/live`) · ⏳ not implemented

## 1. Decisions taken with the product owner

| Topic | Decision |
|---|---|
| Backend | The Django REST API in `backend/` is the contract (`backend/docs/api/openapi.yaml`). The app talks to it through one `ApiClient`; repositories map its representation to the app's domain models. The in-memory fake backend used before the server existed has been retired. |
| Language | Arabic (default, RTL) + English. |
| Roles in the mobile app | Student, Library, Admin — one app, role-based shells. |
| Word & other formats (FR-054) | The server accepts PDF and images only (`pdf, jpg, jpeg, png, webp`, narrowed by the admin setting). Office files are refused with a message asking for a PDF, so the viewer only ever renders PDF or images. |

## 2. Assumptions (open to client confirmation)

| # | Requirement | Assumption |
|---|---|---|
| A1 | FR-001/FR-005 | Accounts are created by the admin only (no self-registration). Admin sets a temporary initial password. |
| A2 | FR-004 | Reset = emailed one-time link (`unilect://app/reset-password?uid&token`, valid 1 h) → new password. The link opens the app or can be pasted. The server always answers 202 (no account enumeration). |
| A3 | FR-007 | Editable profile fields: students `phone`; library/admin `full_name` and `phone`. Everything else is protected. Password change is also offered; admin-created accounts must change their temporary password first. |
| A4 | FR-008 | Device identity = random UUID v4 generated on first launch and kept in secure storage (Keychain on iOS / EncryptedSharedPreferences-backed Keystore on Android). Platform + model are sent for display only. On Android, uninstalling the app wipes the ID → the student must request a device change (documented, by design). |
| A5 | FR-019 | Terms (الفصول) are defined per faculty (backend assumption A-8). |
| A6 | FR-020 | Specializations belong to a faculty; a subject may be linked to zero or more specializations (zero = common to all). |
| A7 | FR-060 | A library is an entity with a scope (whole universities, faculties and/or single courses); each library account belongs to one library. Content is in scope when its course is. |
| A8 | FR-066 | "Require admin review before publishing" is an admin setting (off by default). When on, a library "publish" becomes `pendingReview`. |
| A9 | FR-042/FR-065 | Content status: `draft`, `pending_review`, `published`, `archived`. Admin takedown = archive (or delete). Students see `published` only. |
| A10 | FR-057 | Watermark shows the server-issued, non-identifying viewer code (`watermark_text`, e.g. `UL-4F7K2…`) + date; always on. |
| A11 | FR-058 | Android: `FLAG_SECURE` on the viewer. iOS: screen-recording/mirroring detection blurs content; iOS cannot block screenshots — the UI never claims full protection. |
| A12 | FR-071 | Students "follow" subjects; new published content in followed subjects produces a notification (server-side). Push delivery (FCM/APNs) is out of scope; notifications are in-app (FR-070 "or agreed channel"). |
| A13 | FR-055/FR-076 | Files are fetched as bytes from an authenticated endpoint and kept **in memory only** (never written to disk, never exposed as a URL). |

## 3. Requirements → features mapping

| FR | Title | Feature module / screen | Status |
|---|---|---|---|
| 001 | Create student account | admin/users → user form (role student) | ✅ |
| 002 | Login | auth → LoginScreen | ✅ |
| 003 | Logout | profile → logout; tokens wiped; router guard | ✅ |
| 004 | Password recovery | auth → Forgot password (email → link → new password), deep link `/reset-password` | ✅ |
| 005 | Account management | admin/users → list, create, edit, disable, enable | ✅ |
| 006 | Roles & permissions | `UserRole` + role-shell router guards; server 403 handling | ✅ / 🟡 |
| 007 | Profile update | profile → ProfileScreen (allowed fields only) | ✅ |
| 008 | First device registration | core/device `DeviceIdentity` sent on login | ✅ / 🟡 |
| 009 | Server device check | `X-Device-ID` header on every request; `device_mismatch` → forced logout | ✅ / 🟡 |
| 010 | Block second device | login `device_not_bound` → DeviceBlockedScreen with explanation | ✅ |
| 011 | Device change request | DeviceBlockedScreen form (optional reason) | ✅ |
| 012 | Review device request | admin/devices → approve / reject with note | ✅ |
| 013 | Unbind old device | server on approval; old device forced out on next call | 🟡 |
| 014 | Revoke old sessions | server; app handles `session_revoked` | 🟡 / ✅ |
| 015 | Device log | admin/devices → Device log tab | ✅ |
| 016–022 | Universities, faculties, years, terms, specializations, subjects, doctors | admin/structure → generic managed lists + forms; doctors linked to subjects | ✅ |
| 023 | Ordering | drag-to-reorder in admin lists; `sortOrder` respected in browse | ✅ |
| 024–029 | Browse hierarchy | student/browse screens (university → faculty → year → subject → doctor → lectures) | ✅ |
| 030 | Exam questions | subject screen "Exams" tab | ✅ |
| 031 | Search | student/search | ✅ |
| 032 | Filters | search filter sheet (university/faculty/year/subject/doctor/type) | ✅ |
| 033 | Content details | ContentDetailsScreen (metadata before opening) | ✅ |
| 034 | Favorites | server-side favorites; Favorites tab | ✅ |
| 035–038 | Upload lecture, metadata, classification, ordering | library/upload → ContentEditorScreen | ✅ |
| 039–040 | Edit / delete / archive | library/content actions | ✅ |
| 041 | Replace file + versions | editor → replace file; versions list | ✅ |
| 042 | Publish states | status chips, actions | ✅ |
| 043 | File validation | client pre-check (extension/size from server config) + server errors displayed | ✅ / 🟡 |
| 044 | Preview before publish | editor → Preview step (metadata + file) | ✅ |
| 045–049 | Exam files (classification, year, type, edit/delete) | editor in "exam" mode | ✅ |
| 048 | Manageable exam types | admin/structure → exam types | ✅ |
| 050 | Filter exams | subject Exams tab filters (year, term, type, doctor) | ✅ |
| 051–053 | In-app viewer, PDF, images | viewer → SecureViewerScreen (pdfrx / photo_view) | ✅ |
| 054 | Word & others | server refuses Office files with a clear message; PDF/images only | ✅ / 🟡 |
| 055 | No direct download | no download/share UI; bytes in memory only | ✅ |
| 056 | File access authorization | server; app shows 403/404 states | 🟡 |
| 057 | Watermark | viewer overlay with the server's viewer code | ✅ |
| 058 | Screenshot restriction | platform channel (Android FLAG_SECURE, iOS capture blur) | ✅ |
| 059–060 | Library accounts & scope | admin/structure → Libraries (scope picker); admin/users (role library → library) | ✅ |
| 061 | Library content dashboard | library/dashboard with search & filters | ✅ |
| 062 | Library stats | library/dashboard stat tiles | ✅ |
| 063 | Batch upload | library/batch-upload with per-file result | ✅ |
| 064 | Admin dashboard | admin/dashboard KPIs | ✅ |
| 065 | Manage all content | admin/content (same manager, unrestricted) + archive/delete | ✅ |
| 066 | Review before publish | settings toggle + admin approve/reject queue | ✅ |
| 067 | Device requests sorting | filters by status, sort by date | ✅ |
| 068 | Audit log | admin/audit log | ✅ |
| 069 | System settings | admin/settings (file limits, allowed types, review, follower notifications) + exam types, lecture categories | ✅ |
| 070 | Device decision notification | server creates notification; notifications center | ✅ / 🟡 |
| 071 | New content notification | follow subject toggle; server fan-out | ✅ / 🟡 |
| 072 | Notification center | notifications screen with read state | ✅ |
| 073 | Report content | content details → report sheet | ✅ |
| 074 | Manage reports | admin/reports with status + notes history | ✅ |
| 075 | One active device | server rule (database constraint) | 🟡 |
| 076 | Private file storage | server rule; app never receives URLs | 🟡 / ✅ |
| 077 | Server-side authorization | server rule; app maps 403 | 🟡 |
| 078 | Mandatory classification | client form validation + server `incomplete_content` / `validation_error` | ✅ / 🟡 |
| 079 | Published only for students | server rule; contract | 🟡 |
| 080 | Secure logging | server; app never logs tokens/passwords (redacting log interceptor) | 🟡 / ✅ |

## 4. Architecture

- **Feature-first** under `lib/features/<feature>/{data,domain,presentation}`; shared code in `lib/core`.
- **State**: Riverpod 3 (`Notifier`/`AsyncNotifier`/`FutureProvider`) — testable via overrides, no codegen.
- **Navigation**: go_router with `StatefulShellRoute` per role and a redirect guard driven by the session state.
- **Networking**: single Dio `ApiClient`; interceptors for auth header, device header, single-flight token refresh, error mapping to typed `AppFailure`, and redacted debug logging.
- **Storage**: flutter_secure_storage for tokens + device install ID. Nothing else is persisted.
- **DI**: Riverpod providers (overridable in tests).
- **Models**: hand-written immutable classes with `fromJson`/`toJson` (no build_runner).

## 5. Implementation stages

1. Project setup, theme/brand, l10n, core networking/storage.
2. Auth (login/logout/reset), session & device binding, device-blocked flow.
3. Student browse → content details → secure viewer; search & filters; favorites.
4. Library: dashboard/stats, upload/edit/replace/preview, batch upload.
5. Admin: dashboard, users, structure, content & review, device requests/log, audit log, settings, reports.
6. Notifications, reports, profile.
7. Tests (unit, widget, integration), format/analyze, platform config, docs.

## 6. Progress & verification (2026-10-12, integrated with the backend)

| Check | Result |
|---|---|
| `dart format lib test integration_test` | clean |
| `flutter analyze` | No issues found |
| `flutter test` | 39 passed (unit, model parsing, widget flows on a stubbed transport in the API's format, AR/EN + RTL/LTR); live suite skipped without a server |
| `UNILECT_API=… flutter test test/live` | 16/16 passed against the Django API (`settings.e2e`, own database, `seed_demo`), twice in a row on the same database |
| Backend `pytest --cov` | 302 passed, 96.9 % branch coverage |
| Integration test on device | updated for the real API, **not run** (no emulator on the dev machine) |
| iOS build | **not verified**: requires macOS + Xcode |
