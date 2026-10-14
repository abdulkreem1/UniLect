# UniLect

Flutter app (Android + iOS) for university lectures and past exam papers with
device-bound student accounts, scoped library publishing, and an admin console.
Arabic (RTL, default) and English.

- Requirements analysis, decisions, and the FR → feature map: [`docs/REQUIREMENTS_MAPPING.md`](docs/REQUIREMENTS_MAPPING.md)
- Backend: the Django REST API in [`../../backend`](../../backend). Its contract is
  [`backend/docs/api/openapi.yaml`](../../backend/docs/api/openapi.yaml) (also live at `/api/v1/docs/`)
  and [`backend/docs/02-api-reference.md`](../../backend/docs/02-api-reference.md).

## Backend integration

The app talks to the real UniLect API (`/api/v1`) through one networking client
(`lib/core/network`). Every feature repository maps the API's representation
(snake_case, integer catalog ids, DRF pages `{count, next, results}`, the
`{"error": {code, message, details}}` envelope) to the app's domain models, so
screens never see wire formats.

| Concern | How the app handles it |
|---|---|
| Sign-in | `POST auth/login/` with `device {installation_id, platform, model}`; `X-Device-ID` on every request, refresh included |
| Expired access token | `token_not_valid` → one shared `auth/refresh/` (rotating refresh token), then the request is retried |
| Session ended | `session_revoked`, `account_disabled`, `device_mismatch` (or any other 401) wipe tokens and return to login with the reason |
| Second device | `device_not_bound` → device-blocked screen; the request is filed with the restricted `device_change_token` |
| Temporary password | accounts created/reset by an admin have `must_change_password`; the router confines the user to the change-password screen until it is done |
| Password reset | the server emails `unilect://app/reset-password?uid=…&token=…`; the link opens the app (Android intent filter / iOS URL scheme) or can be pasted |
| Library pickers | catalog lists are requested with `in_scope=true`, so a library only sees the part of the tree it may publish in |
| Upload limits | `GET config/` (any role) for the pre-check; the server validates again (magic bytes, size, PDF structure) |
| Watermark | the server's `watermark_text` / `X-Watermark-Text` code is overlaid on the viewer |

## Run

```bash
flutter pub get
```

Start the backend first (see the backend README). For the emulator, let it
listen on all interfaces and load the demo data once:

```bash
python manage.py seed_demo
```

```bash
python manage.py runserver 0.0.0.0:8000
```

Then, in a debug build, the app uses `http://10.0.2.2:8000/api/v1` on the
Android emulator and `http://127.0.0.1:8000/api/v1` elsewhere:

```bash
flutter run
```

On a physical phone (same network), pass the computer's address and add it to
the backend's `ALLOWED_HOSTS`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1
```

Release builds always need `API_BASE_URL` (HTTPS). Plain HTTP is only allowed in
Android debug builds and to local addresses on iOS.

Demo accounts (all with password `UniLect#2026`, created by `seed_demo`):

| Account | Shows |
|---|---|
| `admin@unilect.test` | admin console, a pending device request, an open report, content awaiting review |
| `library@unilect.test` | library scoped to Damascus University |
| `library.aleppo@unilect.test` | library scoped to one Aleppo faculty |
| `student@unilect.test` | the first sign-in binds the device |
| `student2@unilect.test` | already bound to another device → device-change request |
| `disabled@unilect.test` | disabled account |

## Architecture

Feature-first, with `data` / `domain` / `application` / `presentation` per feature:

```
lib/
  main.dart, app/            app root, go_router (role guards), role shells, routes
  core/
    config/                  --dart-define configuration (API_BASE_URL)
    network/                 ApiClient (pages, files, multipart), AuthInterceptor (headers,
                             single-flight refresh, session termination), error envelope →
                             AppFailure, redacting log
    storage/                 secure storage (Keychain / Keystore), token storage
    device/                  install-ID identity used for device binding
    security/                screen-capture protection channel
    application/             generic paged-list notifier + view
    l10n/, theme/, widgets/  localization helpers, brand theme, shared UI kit
    providers.dart           composition root (all dependencies overridable)
  features/
    auth/                    login, session controller, password reset, forced password change
    devices/                 device-blocked flow, admin requests + device log
    academic/                browse hierarchy, structure & library read/write models
    content/                 student content, search, favorites, follows, details
    viewer/                  secure in-app PDF/image viewer (watermark, no download)
    library/                 dashboard, content manager, editor, batch upload
    admin/                   dashboard, users, structure, libraries, audit, settings, reports
    notifications/, profile/, reports/, settings/
  l10n/                      app_ar.arb (template), app_en.arb
```

- **State / DI:** Riverpod 3 (no code generation). Every dependency is a provider, so tests can override it.
- **Navigation:** go_router with `StatefulShellRoute` per role and a redirect guard. The guard is UX only; the server enforces every permission.
- **Models:** hand-written immutable classes with strict JSON parsing of the API representation.

## Security notes

- Tokens and the device install ID are kept only in secure storage. Android backups are disabled (`allowBackup=false`), so a restored backup cannot pose as the bound device.
- Every request carries `X-Device-ID`. A copied token is useless on another installation (`device_mismatch`).
- Files are fetched as bytes from authenticated endpoints and held **in memory only**. There are no URLs and no download, share or open-in actions.
- Viewer protections:
  - a watermark with the server-issued, non-identifying viewer code;
  - Android `FLAG_SECURE`;
  - iOS hides content while the screen is recorded or mirrored. iOS screenshots cannot be blocked, and the UI says so.
- The debug HTTP log prints method, path and status only, never headers or bodies.

## Quality gates

```bash
dart format lib test integration_test
```

```bash
flutter analyze
```

```bash
flutter test
```

`flutter test` runs everything that needs no server. The live API suite runs
the app's real networking stack and repositories against a running backend;
give it its own database (see the backend README, "Mobile app end-to-end
tests"), then:

```bash
UNILECT_API=http://127.0.0.1:8001/api/v1 flutter test test/live
```

The integration test needs a device or emulator and a seeded backend:

```bash
flutter test integration_test -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

| Suite | What it covers |
|---|---|
| `test/live` | against the real API: login/logout, token refresh + replay detection, password reset, device binding → change request → admin approval → unbind, catalog browsing and ordering, search, file delivery + watermark, favorites/follows/reports, library upload → publish → new version → archive/restore/delete, mandatory fields, scope and file validation, review workflow, follower notifications, admin users/catalog/libraries/audit/settings |
| `test/widget` | the real app with a stubbed transport answering in the API's format: login validation/errors and request shape, student browse → details, device-blocked request with the restricted token, forced password change, logout, revoked session, library dashboard, admin device approval, admin account creation, Arabic/English + RTL/LTR |
| `test/core`, `test/domain` | error envelope mapping, route guard, token storage, model parsing, draft validation and payloads, upload pre-check, query models, report transitions |
| `integration_test/` | on-device: open a lecture in the real PDF viewer; editor validation |

## Before production

1. Deploy the backend (see its README) and build with `--dart-define=API_BASE_URL=https://…/api/v1`.
2. Set the backend's `PASSWORD_RESET_URL_TEMPLATE` to the app link (`unilect://app/reset-password?uid={uid}&token={token}`), or to a web page that forwards to it.
3. Set up Android release signing (the release build currently uses the debug key, per the Flutter template) and the iOS team, bundle ID and provisioning.
4. Confirm the open assumptions A1–A13 in the requirements document with the client.
