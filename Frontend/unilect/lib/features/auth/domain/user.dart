import '../../../core/models/json.dart';

enum UserRole { student, library, admin }

enum AccountStatus { active, disabled }

/// A student's bound device as reported to admins. The server never exposes
/// the installation id itself.
class DeviceInfo {
  const DeviceInfo({required this.platform, this.model, this.boundAt});

  /// `active_device` of an admin user, or a device inside a change request.
  factory DeviceInfo.fromJson(Json json) => DeviceInfo(
    platform: json['platform'] as String? ?? 'android',
    model: textOrNull(json['model_name']),
    boundAt: parseDateOrNull(json['bound_at']),
  );

  final String platform;
  final String? model;
  final DateTime? boundAt;

  String get label =>
      [platform == 'ios' ? 'iOS' : 'Android', ?model].join(' · ');
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    required this.status,
    required this.createdAt,
    this.studentNumber,
    this.phone,
    this.universityId,
    this.universityName,
    this.libraryId,
    this.libraryName,
    this.mustChangePassword = false,
    this.boundDevice,
    this.lastLogin,
  });

  /// Parses the login `user`, `GET me/` and the admin user representation.
  factory AppUser.fromJson(Json json) => AppUser(
    id: idOf(json['id']),
    role: enumByName(UserRole.values, json['role'], UserRole.student),
    fullName: json['full_name'] as String? ?? '',
    email: json['email'] as String,
    status: (json['is_active'] as bool? ?? true)
        ? AccountStatus.active
        : AccountStatus.disabled,
    createdAt: parseDate(json['date_joined']),
    studentNumber: textOrNull(json['student_number']),
    phone: textOrNull(json['phone']),
    universityId: idOrNull(json['university']),
    universityName: textOrNull(json['university_name']),
    libraryId: idOrNull(json['library']),
    libraryName: textOrNull(json['library_name']),
    mustChangePassword: json['must_change_password'] as bool? ?? false,
    boundDevice: json['active_device'] == null
        ? null
        : DeviceInfo.fromJson(json['active_device'] as Json),
    lastLogin: parseDateOrNull(json['last_login']),
  );

  final String id;
  final UserRole role;
  final String fullName;
  final String email;
  final AccountStatus status;
  final DateTime createdAt;
  final String? studentNumber;
  final String? phone;

  /// Students: the university the student number belongs to.
  final String? universityId;
  final String? universityName;

  /// Library staff: the library whose scope they work in (FR-059/060).
  final String? libraryId;
  final String? libraryName;

  /// Set for accounts created or reset by an administrator: the API refuses
  /// everything except changing the password until it is changed.
  final bool mustChangePassword;
  final DeviceInfo? boundDevice;
  final DateTime? lastLogin;

  bool get isActive => status == AccountStatus.active;

  AppUser copyWith({bool? mustChangePassword}) => AppUser(
    id: id,
    role: role,
    fullName: fullName,
    email: email,
    status: status,
    createdAt: createdAt,
    studentNumber: studentNumber,
    phone: phone,
    universityId: universityId,
    universityName: universityName,
    libraryId: libraryId,
    libraryName: libraryName,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    boundDevice: boundDevice,
    lastLogin: lastLogin,
  );

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String firstChar(String s) => String.fromCharCode(s.runes.first);
    return parts.length == 1
        ? firstChar(parts.first)
        : '${firstChar(parts.first)} ${firstChar(parts.last)}';
  }
}
