import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/user.dart';
import '../../devices/domain/device_models.dart';
import '../../reports/domain/content_report.dart';
import '../../settings/domain/client_config.dart';
import '../domain/admin_models.dart';

class UserQuery {
  const UserQuery({this.text = '', this.role, this.status});

  final String text;
  final UserRole? role;
  final AccountStatus? status;

  /// Query of `admin/users/`.
  Map<String, dynamic> toQuery() => {
    'search': text.trim(),
    'role': role?.name,
    'is_active': status == null ? null : status == AccountStatus.active,
  };

  UserQuery copyWith({
    String? text,
    Nullable<UserRole>? role,
    Nullable<AccountStatus>? status,
  }) => UserQuery(
    text: text ?? this.text,
    role: role == null ? this.role : role.value,
    status: status == null ? this.status : status.value,
  );

  @override
  bool operator ==(Object other) =>
      other is UserQuery &&
      other.text == text &&
      other.role == role &&
      other.status == status;

  @override
  int get hashCode => Object.hash(text, role, status);
}

/// Fields of the admin create/edit account form (FR-001, FR-005, FR-059).
class UserForm {
  const UserForm({
    required this.role,
    required this.fullName,
    required this.email,
    this.studentNumber,
    this.universityId,
    this.libraryId,
    this.phone,
    this.initialPassword,
  });

  final UserRole role;
  final String fullName;
  final String email;

  /// Students: number + university (the number is unique per university).
  final String? studentNumber;
  final String? universityId;

  /// Library staff: the library they work for.
  final String? libraryId;
  final String? phone;
  final String? initialPassword;

  /// Body of `admin/users/`. Fields that don't apply to the role are sent as
  /// null (the server clears them). New accounts must change the initial
  /// password at first sign-in.
  Json toJson({required bool create}) => {
    'role': role.name,
    'full_name': fullName.trim(),
    'email': email.trim(),
    'phone': phone?.trim() ?? '',
    'student_number': role == UserRole.student ? studentNumber?.trim() : null,
    'university': role == UserRole.student ? intId(universityId) : null,
    'library': role == UserRole.library ? intId(libraryId) : null,
    if (create) ...{'password': initialPassword, 'must_change_password': true},
  };
}

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<AdminDashboard> dashboard() async =>
      AdminDashboard.fromJson(await _api.get<Json>('/admin/dashboard/'));

  // ── Users ──
  Future<Paged<AppUser>> users(UserQuery query, {int page = 1}) => _api.getPage(
    '/admin/users/',
    AppUser.fromJson,
    page: page,
    query: query.toQuery(),
  );

  Future<AppUser> user(String id) async =>
      AppUser.fromJson(await _api.get<Json>('/admin/users/$id/'));

  Future<AppUser> createUser(UserForm form) async => AppUser.fromJson(
    await _api.post<Json>('/admin/users/', body: form.toJson(create: true)),
  );

  /// Changing role, email, library or university ends the user's sessions.
  Future<AppUser> updateUser(String id, UserForm form) async =>
      AppUser.fromJson(
        await _api.patch<Json>(
          '/admin/users/$id/',
          body: form.toJson(create: false),
        ),
      );

  /// Deactivating revokes every session immediately (FR-005).
  Future<AppUser> setUserEnabled(String id, {required bool enabled}) async =>
      AppUser.fromJson(
        await _api.post<Json>(
          '/admin/users/$id/${enabled ? 'activate' : 'deactivate'}/',
        ),
      );

  /// Sets a new password, revokes all sessions; the user must change it at
  /// next sign-in.
  Future<void> setUserPassword(String id, String password) => _api.post<void>(
    '/admin/users/$id/set-password/',
    body: {'password': password, 'must_change_password': true},
  );

  /// Unbinds a student's device (lost phone): the next sign-in binds again.
  Future<void> resetDevice(String id) =>
      _api.post<void>('/admin/users/$id/reset-device/');

  // ── Devices ──
  Future<List<DeviceChangeRequest>> deviceRequests({
    DeviceChangeStatus? status,
    bool newestFirst = true,
  }) => _api.getAll(
    '/admin/device-change-requests/',
    DeviceChangeRequest.fromJson,
    query: {
      'status': status?.name,
      'ordering': newestFirst ? '-created_at' : 'created_at',
    },
  );

  Future<DeviceChangeRequest> decideDeviceRequest(
    String id, {
    required bool approve,
    String? note,
  }) async => DeviceChangeRequest.fromJson(
    await _api.post<Json>(
      '/admin/device-change-requests/$id/${approve ? 'approve' : 'reject'}/',
      body: {'note': note?.trim() ?? ''},
    ),
  );

  /// Device binding history from the audit trail (FR-015).
  Future<Paged<DeviceLogEntry>> deviceLogs({int page = 1}) => _api.getPage(
    '/admin/audit-logs/',
    DeviceLogEntry.fromAudit,
    page: page,
    pageSize: 30,
    query: {'category': 'device'},
  );

  // ── Audit / settings / reports ──
  Future<Paged<AuditLogEntry>> auditLogs({String? category, int page = 1}) =>
      _api.getPage(
        '/admin/audit-logs/',
        AuditLogEntry.fromJson,
        page: page,
        pageSize: 30,
        query: {'category': category},
      );

  Future<ClientConfig> settings() async =>
      ClientConfig.fromJson(await _api.get<Json>('/admin/settings/'));

  /// Applies to subsequent operations only (FR-069).
  Future<ClientConfig> saveSettings(ClientConfig config) async =>
      ClientConfig.fromJson(
        await _api.patch<Json>('/admin/settings/', body: config.toJson()),
      );

  Future<List<ContentReport>> reports({ReportStatus? status}) => _api.getAll(
    '/admin/reports/',
    ContentReport.fromJson,
    query: {'status': status?.apiValue},
  );

  /// Moves the report to [status] (with an optional note), or only records
  /// the note when the status is unchanged. The reporter is notified when a
  /// report is resolved or dismissed.
  Future<ContentReport> updateReport(
    ContentReport report, {
    required ReportStatus status,
    String? note,
  }) async {
    final text = note?.trim() ?? '';
    if (status != report.status) {
      return ContentReport.fromJson(
        await _api.post<Json>(
          '/admin/reports/${report.id}/transition/',
          body: {'status': status.apiValue, 'note': text},
        ),
      );
    }
    if (text.isNotEmpty) {
      await _api.post<Json>(
        '/admin/reports/${report.id}/notes/',
        body: {'note': text},
      );
    }
    return ContentReport.fromJson(
      await _api.get<Json>('/admin/reports/${report.id}/'),
    );
  }
}
