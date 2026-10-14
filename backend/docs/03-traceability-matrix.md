# Requirements → Implementation → Tests

Status legend: ✅ implemented and tested · 🟡 partly implemented, or implemented under an assumption (see notes) · 📱 client-side responsibility (the backend supports it).
Test paths are relative to `tests/`. The whole suite: 290 tests, 96.7% branch coverage (gate: 95%).

## 2.1 Accounts & access

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 001 | Admin creates student account | `accounts.serializers.AdminUserSerializer`, `services.admin_create_user`; `User` constraints (unique email CI, student number per university) | `test_accounts_admin.py::TestCreateUsers` | ✅ |
| 002 | Login, clear error | `accounts.views.LoginView`, `services.check_credentials/login` | `test_auth.py::TestLogin` | ✅ |
| 003 | Logout ends session | `AuthSession` revocation, `LogoutView`, `SessionJWTAuthentication` | `test_auth.py::TestLogout` | ✅ |
| 004 | Secure password recovery | `services.passwords` (one-time email token, 1 h) | `test_auth.py::TestPasswordFlows`; real SMTP delivery verified in the stack run | ✅ |
| 005 | Create/edit/disable/re-enable accounts | `AdminUserViewSet` + `activate`/`deactivate`/`revoke-sessions`; auth class rejects inactive users; role change releases devices | `test_accounts_admin.py::TestRoleEnforcement`, `test_auth.py::TestProtectedAccess`, `test_policies.py::TestRoleChange`, `test_edge_cases.py::TestSessionsAdmin` | ✅ |
| 006 | Role & permissions per account | `User.role`, `core.permissions`, scoped selectors | `test_hardening.py` (permission matrix), `test_accounts_admin.py` | ✅ |
| 007 | Profile; protected fields rejected | `MeView`, `MeSerializer.WRITABLE_BY_ROLE` | `test_accounts_admin.py::TestProfile`, `test_hardening.py` | ✅ |

## 2.2 Single-device binding

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 008 | Bind first device | `devices.services.resolve_login_device` (row lock + partial unique index) | `test_devices.py::TestBinding`, `test_concurrency.py::test_simultaneous_first_logins_bind_exactly_one_device` | ✅ |
| 009 | Server checks device on every protected request | `SessionJWTAuthentication._check_device`, `refresh_session` | `test_devices.py::TestBinding`, `test_auth.py::TestRefresh` | ✅ |
| 010 | Refuse second device with explanation | `DeviceNotBound` (403 + restricted token + pending info) | `test_devices.py::TestBinding::test_second_device_is_refused_with_explanation` | ✅ |
| 011 | Device-change request with optional reason | `DeviceChangeRequestFromNewDeviceViewSet`, `services.create_change_request` | `test_devices.py::TestChangeRequestFlow` | ✅ |
| 012 | Admin approves/rejects; decision recorded; student told | `approve_change_request`/`reject_change_request` (decided_by/at/note), notification in the site language | `test_devices.py::TestChangeRequestFlow`, `test_concurrency.py::test_approve_and_reset_racing_never_deadlock`, `test_misc.py::TestArabicLocalisation` | ✅ |
| 013 | Old device loses access | old `StudentDevice` → revoked | `test_full_approval_flow` | ✅ |
| 014 | Old sessions/tokens invalidated | all `AuthSession`s revoked on approval/reset | `test_full_approval_flow` | ✅ |
| 015 | Device change log | `AuditLog(category=device)`, `admin/users/{id}/devices/` | `test_full_approval_flow`, `TestAdminReset::test_device_history` | ✅ |

## 2.3 Academic structure

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 016 | Universities, enable/disable | `University`, `AdminUniversityViewSet` | `test_academics.py` | ✅ |
| 017 | Faculty requires valid university | FK PROTECT + serializer | `test_academics.py::test_faculty_requires_valid_university` | ✅ |
| 018 | Levels per faculty | `Level` (unique number per faculty) | `test_academics.py` | ✅ |
| 019 | Semesters | `Semester` per faculty (A-8) | `test_academics.py`, content exam tests | ✅ |
| 020 | Specializations | `Specialization` + course M2M (A-9) | `test_specialization_filter_includes_common_courses` | ✅ |
| 021 | Courses linked to path | `Course.level` (university/faculty derived) | `test_courses_of_level_hide_inactive_chain` | ✅ |
| 022 | Instructors linked to courses | `Instructor`, `CourseInstructor` | `test_link_instructor_once`, `test_course_instructors_in_defined_order` | ✅ |
| 023 | Display order | `sort_order` on all catalog entities and links | `test_order_follows_sort_order` | ✅ |

## 2.4 Student browsing & search

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 024–028 | Universities → faculties → levels → courses → instructors | `academics.selectors.visible_*`, catalog viewsets | `test_academics.py::TestStudentBrowsing` | ✅ |
| 029 | Instructor's lectures (published only) | `catalog/contents/?course=&instructor=&kind=lecture` | `test_content_student.py::TestVisibility`, `TestSearchAndFilters` | ✅ |
| 030 | Exam questions per course by category | `?kind=exam&course=…&exam_type=…` | `TestSearchAndFilters::test_filters` | ✅ |
| 031 | Keyword search within visible content | `core.filters.ArabicSearchFilter`, `core.text.normalize`, `ContentItem.search_document` (trigram index) | `test_search.py`, `test_search_never_returns_unpublished` | ✅ |
| 032 | Filter by university/faculty/year/course/instructor/type | `ContentFilter` | `test_filters` | ✅ |
| 033 | Metadata before opening | `CatalogContentSerializer` | `test_detail_metadata_before_opening` | ✅ |
| 034 | Favorites persist | `Favorite`, `FavoriteViewSet` | `TestFavorites` | ✅ |

## 2.5 Lectures

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 035 | Upload with type/size check | `content.validation.validate_upload`, `services.create_content` | `test_content_manage.py::TestCreate`, `TestUploadValidation` | ✅ |
| 036 | Title/description/course/instructor/category | `ContentWriteSerializer`, `validate_publishable` | `TestWorkflow::test_cannot_publish_lecture_without_category_or_instructor` | ✅ |
| 037 | Classification to the right path | `validate_classification` (scope, instructor↔course) | `TestCreate::test_course_outside_scope_rejected`, `test_instructor_must_be_linked_to_course` | ✅ |
| 038 | Lecture order | `lecture_number`; default ordering | `test_default_order_by_lecture_number` | ✅ |
| 039 | Edit within scope | `ManageContentViewSet.partial_update` + scoped selector | `TestScope`, `TestWorkflow::test_update_title` | ✅ |
| 040 | Delete or archive | `services.delete` / `archive` | `test_library_deletes_only_drafts`, `test_archive_and_restore` | ✅ |
| 041 | Replace file, keep history | `ContentFile` versions, `replace_file` | `TestFileVersions` | ✅ |
| 042 | Draft/published/archived | `ContentItem.Status`, workflow services | `TestWorkflow`, `TestVisibility` | ✅ |
| 043 | File validation with reason | `validation.py` reasons | `TestUploadValidation` | ✅ |
| 044 | Preview before publishing | `GET manage/contents/{id}/file/` on drafts | `test_preview_draft_file` | ✅ |

## 2.6 Exam papers

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 045 | Upload exam questions | `kind=exam` | `test_create_exam_paper` | ✅ |
| 046 | Course/instructor/level/semester classification | exam fields + `validate_classification` | `test_exam_semester_must_match_faculty` | ✅ |
| 047 | Academic year | `exam_year` (1950–2100, DB check) | `test_exam_year_range`, filters | ✅ |
| 048 | Exam type from managed list | `ExamType`, `admin/exam-types/` | `TestLookupsAdmin` | ✅ |
| 049 | Edit/delete/archive in scope | as FR-039/040 | `TestScope` | ✅ |
| 050 | Filter by course/year/semester/type | `ContentFilter` | `test_filters` | ✅ |

## 2.7 Content protection

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 051–053 | In-app viewer, PDF & images | Inline streaming endpoint; page count metadata | `TestProtectedFile` | ✅ backend / 📱 viewer UI |
| 054 | Word & other formats | Clear `unsupported_format` rejection; conversion deferred (A-13) | `TestUploadValidation` (docx) | 🟡 |
| 055 | No direct download / public link | No storage URL anywhere; `inline`, `no-store` | `test_stream_headers`, `test_no_storage_url_anywhere` | ✅ backend / 📱 no download button |
| 056 | Identity + permission + device checked before serving | auth class + `visible_contents` on every call | `test_unauthenticated_and_wrong_device_rejected`, `TestVisibility` | ✅ |
| 057 | Watermark (optional) | `watermark_text` (non-PII viewer code) in detail + header | `test_stream_headers` | ✅ data / 📱 overlay |
| 058 | Screenshot restriction (optional) | — | — | 📱 (`FLAG_SECURE` / iOS capture detection) |

## 2.8 Libraries

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 059 | Create library account with scope | `admin/libraries/` + `admin/users/` (role=library) | `TestLibrariesAdmin`, `test_library_account_requires_library` | ✅ |
| 060 | Scope = universities/faculties/courses | `Library.scope_*`, `libraries.selectors.scope_course_q` | `TestScope::test_course_level_scope`, `test_scope_revocation_removes_access` | ✅ |
| 061 | Library content dashboard list + search/filter | `GET manage/contents/` | `test_filters_search_and_stats` | ✅ |
| 062 | Library statistics | `manage/stats/` | `test_filters_search_and_stats` | ✅ |
| 063 | Bulk upload, per-file result | `manage/contents/bulk/` | `TestBulkUpload` | ✅ |

## 2.9 Admin panel

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 064 | Dashboard summary | `content.dashboard.AdminDashboardView` | `TestAdminDashboard` | ✅ |
| 065 | Admin manages all content | `manageable_contents` (admin = all) | `TestScope::test_admin_can_edit_and_archive_any` | ✅ |
| 066 | Review before publishing (optional) | `SystemSettings.require_content_review`, `approve`/`reject`, re-review of library edits | `test_review_required_flow`, `test_pending_review_not_visible`, `test_policies.py::TestReviewPolicy` | ✅ (off by default) |
| 067 | Device requests list, sort by status/date | `AdminDeviceChangeRequestViewSet` | `test_full_approval_flow` | ✅ |
| 068 | Operations log | `AuditLog`, `AuditedModelViewSetMixin`, service-level `audit.record` | `TestAudit`, device/content tests | ✅ |
| 069 | System settings | `SystemSettings` + hard limits | `TestSettings`, `test_size_limit_from_settings` | ✅ |

## 2.10 Notifications

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 070 | Device decision notification | `notifications.notify` in approve/reject | `test_full_approval_flow`, `test_rejection_keeps_old_device_and_notifies` | ✅ in-app |
| 071 | New content for followed courses | `CourseFollow`, `services.notify_followers` (first publication only) | `TestFollowNotifications` | ✅ in-app |
| 072 | Notification centre with read state | `NotificationViewSet` | `TestNotifications` | ✅ |

## 2.11 Reports

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 073 | Report content | `ContentReportCreateView` | `TestReports` | ✅ |
| 074 | Manage reports with history | `AdminReportViewSet`, `ReportAction` | `TestReports::test_report_lifecycle` | ✅ |

## 2.12 Business rules

| FR | Requirement | Implementation | Tests | Status |
|---|---|---|---|---|
| 075 | One active device | Partial unique index `one_active_device_per_student` + consistent lock order | `test_database_forbids_two_active_devices`, `test_concurrency.py` | ✅ |
| 076 | Private storage, no permanent links | `STORAGES["private"]` (no base URL), streaming / `X-Accel-Redirect` | `test_x_accel_redirect_in_production_mode`; stack run: nginx delivery, range 206, internal path unreachable | ✅ |
| 077 | Server-side permission checks | Permission classes + scoped selectors everywhere | `test_hardening.py` (permission matrix), scope tests | ✅ |
| 078 | No publishing without required fields | Service check + DB check constraint | `test_database_rejects_incomplete_published_row`, workflow tests | ✅ |
| 079 | Students see published & authorised only | `content.selectors.visible_contents` | `TestVisibility` | ✅ |
| 080 | Log errors/sensitive ops without secrets | `audit.scrub`, JSON security logger, JSON 500 handler, proxy-aware client IP | `TestAudit`, `test_password_not_leaked_in_audit_or_response`, `test_edge_cases.py` (500s, formatter), stack run log scan (0 secrets) | ✅ |
