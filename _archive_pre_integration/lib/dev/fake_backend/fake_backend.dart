import 'fake_db.dart';
import 'fake_http.dart';
import 'fake_seed.dart';

part 'handlers/auth_handlers.dart';
part 'handlers/structure_handlers.dart';
part 'handlers/content_handlers.dart';
part 'handlers/manage_handlers.dart';
part 'handlers/admin_handlers.dart';
part 'handlers/user_handlers.dart';

/// DEV ONLY — an in-memory implementation of `docs/api/openapi.yaml`.
///
/// It exists so every app flow can be exercised before the production server
/// is available. It enforces the same rules the real server must enforce
/// (device binding, roles, library scope, publish state) so the client's
/// handling of those rules is real, but it is **not** a backend.
class FakeBackend {
  FakeBackend({FakeDb? db, DateTime Function()? clock})
    : db = db ?? seededFakeDb(),
      _clock = clock ?? DateTime.now {
    _registerAuth();
    _registerUser();
    _registerStructure();
    _registerContent();
    _registerManage();
    _registerAdmin();
  }

  final FakeDb db;
  final DateTime Function() _clock;
  final _router = FakeRouter();

  /// DEV hook: the last password-reset code "emailed" by the fake backend,
  /// surfaced in the UI only while the fake backend is active.
  String? lastIssuedResetCode;

  static const accessTtl = Duration(minutes: 15);
  static const ticketTtl = Duration(minutes: 15);

  DateTime get now => _clock();

  Future<FakeResponse> handle(FakeRequest req) async {
    try {
      return await _router.dispatch(req);
    } on FakeError catch (e) {
      return e.toResponse();
    }
  }

  // ── Helpers shared by handler groups ──────────────────────────────────

  static String iso(DateTime d) => d.toUtc().toIso8601String();

  bool _isAr(FakeRequest r) => (r.header('accept-language') ?? 'ar') == 'ar';

  String _msg(FakeRequest r, String ar, String en) => _isAr(r) ? ar : en;

  /// Authenticates the bearer token and, for students, the bound device
  /// (FR-009, FR-013, FR-014, FR-075). Optionally checks the role (FR-006).
  FUser _auth(FakeRequest r, {Set<String>? roles}) {
    final header = r.header('authorization') ?? '';
    final token = header.startsWith('Bearer ') ? header.substring(7) : '';
    final session = db.sessions[token];
    if (session == null || session.revoked) {
      throw FakeError(
        401,
        'TOKEN_REVOKED',
        _msg(
          r,
          'انتهت الجلسة، يرجى تسجيل الدخول مجدداً',
          'Session ended, please sign in again',
        ),
      );
    }
    if (now.isAfter(session.accessExpiresAt)) {
      throw const FakeError(401, 'TOKEN_EXPIRED', 'Access token expired');
    }
    final user = db.users[session.userId]!;
    if (user.status != 'active') {
      throw FakeError(
        403,
        'ACCOUNT_DISABLED',
        _msg(r, 'الحساب معطّل', 'Account disabled'),
      );
    }
    final deviceId = r.header('x-device-id');
    if (user.role == 'student' &&
        (deviceId != session.installId ||
            user.boundDevice?['installId'] != deviceId)) {
      throw FakeError(
        403,
        'DEVICE_NOT_AUTHORIZED',
        _msg(
          r,
          'هذا الجهاز لم يعد مرتبطاً بحسابك',
          'This device is no longer linked to your account',
        ),
      );
    }
    if (roles != null && !roles.contains(user.role)) {
      throw FakeError(
        403,
        'FORBIDDEN',
        _msg(
          r,
          'ليست لديك صلاحية لهذه العملية',
          'You are not allowed to do this',
        ),
      );
    }
    return user;
  }

  FakeError _notFound(FakeRequest r) => FakeError(
    404,
    'NOT_FOUND',
    _msg(r, 'العنصر غير موجود', 'Item not found'),
  );

  FakeError _validation(FakeRequest r, Map<String, String> fields) => FakeError(
    400,
    'VALIDATION_FAILED',
    _msg(
      r,
      'يرجى استكمال الحقول المطلوبة',
      'Please complete the required fields',
    ),
    fields: fields,
  );

  void _audit(
    FUser actor,
    String action,
    String entityType,
    String entityId,
    String label,
  ) => db.auditLogs.insert(0, {
    'id': db.newId('log'),
    'action': action,
    'actor': actor.actor,
    'entityType': entityType,
    'entityId': entityId,
    'entityLabel': label,
    'createdAt': iso(now),
  });

  void _notify(
    String userId,
    String type,
    String title,
    String body, [
    Map<String, String> data = const {},
  ]) => db.notifications.insert(
    0,
    FNotification(
      id: db.newId('ntf'),
      userId: userId,
      type: type,
      title: title,
      body: body,
      createdAt: now,
      data: data,
    ),
  );

  void _deviceLog(
    FUser user,
    String action, {
    Map<String, String>? device,
    FUser? actor,
    String? note,
  }) => db.deviceLogs.insert(0, {
    'id': db.newId('dlog'),
    'userId': user.id,
    'userName': user.fullName,
    'action': action,
    'device': maskDevice(device),
    'actor': actor?.actor,
    'note': note,
    'createdAt': iso(now),
  });

  void _revokeSessions(String userId, {String? exceptToken}) {
    for (final s in db.sessions.values) {
      if (s.userId == userId && s.accessToken != exceptToken) s.revoked = true;
    }
  }

  Map<String, dynamic> _page(
    List<Object?> all,
    FakeRequest r, [
    int size = 20,
  ]) {
    final page = r.page();
    final pageSize = r.pageSize(size);
    final start = ((page - 1) * pageSize).clamp(0, all.length);
    final end = (start + pageSize).clamp(0, all.length);
    return {
      'items': all.sublist(start, end),
      'page': page,
      'pageSize': pageSize,
      'total': all.length,
    };
  }

  static int _bySort(Map<String, dynamic> a, Map<String, dynamic> b) {
    final c = (a['sortOrder'] as int).compareTo(b['sortOrder'] as int);
    return c != 0 ? c : (a['name'] as String).compareTo(b['name'] as String);
  }

  // ── Academic path & visibility ────────────────────────────────────────

  ({
    Map<String, dynamic> university,
    Map<String, dynamic> faculty,
    Map<String, dynamic> year,
    Map<String, dynamic> subject,
  })?
  _pathOfSubject(String subjectId) {
    final subject = db.item('subjects', subjectId);
    if (subject == null) return null;
    final faculty = db.item('faculties', subject['facultyId'] as String)!;
    return (
      university: db.item('universities', faculty['universityId'] as String)!,
      faculty: faculty,
      year: db.item('years', subject['yearId'] as String)!,
      subject: subject,
    );
  }

  bool _subjectActive(String subjectId) {
    final p = _pathOfSubject(subjectId);
    return p != null &&
        p.university['isActive'] == true &&
        p.faculty['isActive'] == true &&
        p.year['isActive'] == true &&
        p.subject['isActive'] == true;
  }

  /// Students only see published content in active structure (FR-079).
  bool _visibleToStudent(FContent c) {
    if (c.status != 'published' || !_subjectActive(c.subjectId)) return false;
    final doctor = db.item('doctors', c.doctorId);
    return c.doctorId == null || doctor?['isActive'] == true;
  }

  /// Library scope check (FR-060). Admins are unrestricted.
  bool _inScope(FUser user, {String? universityId, String? facultyId}) {
    if (user.role == 'admin') return true;
    final scope = user.scope;
    if (scope == null) return false;
    if (facultyId != null) {
      if (scope['facultyIds']!.contains(facultyId)) return true;
      universityId ??=
          db.item('faculties', facultyId)?['universityId'] as String?;
    }
    return universityId != null &&
        scope['universityIds']!.contains(universityId);
  }

  bool _subjectInScope(FUser user, String subjectId) {
    final subject = db.item('subjects', subjectId);
    return subject != null &&
        _inScope(user, facultyId: subject['facultyId'] as String);
  }

  Map<String, dynamic> _contentJson(
    FContent c, {
    FUser? viewer,
    bool manage = false,
  }) {
    final path = _pathOfSubject(c.subjectId)!;
    final file = c.current;
    return {
      'id': c.id,
      'type': c.type,
      'title': c.title,
      'description': c.description,
      'status': c.status,
      'subjectId': c.subjectId,
      'doctorId': c.doctorId,
      'lectureNumber': c.lectureNumber,
      'examYear': c.examYear,
      'termId': c.termId,
      'examTypeId': c.examTypeId,
      'classification': {
        'universityId': path.university['id'],
        'universityName': path.university['name'],
        'facultyId': path.faculty['id'],
        'facultyName': path.faculty['name'],
        'yearId': path.year['id'],
        'yearName': path.year['name'],
        'subjectName': path.subject['name'],
        'doctorName': db.item('doctors', c.doctorId)?['name'],
        'termName': db.item('terms', c.termId)?['name'],
        'examTypeName': db.item('exam-types', c.examTypeId)?['name'],
      },
      'file': {
        'mimeType': file.mimeType,
        'sizeBytes': file.bytes.length,
        'version': file.version,
        'conversionStatus': file.conversionStatus,
        if (manage) 'originalName': file.originalName,
      },
      if (viewer != null && viewer.role == 'student')
        'isFavorite': viewer.favorites.contains(c.id),
      'reviewNote': manage ? c.reviewNote : null,
      'createdAt': iso(c.createdAt),
      'updatedAt': iso(c.updatedAt),
      'publishedAt': c.publishedAt == null ? null : iso(c.publishedAt!),
    };
  }

  static int _contentOrder(FContent a, FContent b) {
    final la = a.lectureNumber ?? 1 << 20;
    final lb = b.lectureNumber ?? 1 << 20;
    return la != lb ? la.compareTo(lb) : a.createdAt.compareTo(b.createdAt);
  }

  /// Validates uploaded files by extension, size and magic bytes (FR-043).
  ({String mimeType, String conversionStatus}) _validateFile(
    FakeRequest r,
    FakeUpload? file,
  ) {
    if (file == null) {
      throw _validation(r, {'file': 'required'});
    }
    final dot = file.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    final allowed = (db.settings['allowedExtensions'] as List).cast<String>();
    if (!allowed.contains(ext)) {
      throw FakeError(
        400,
        'FILE_TYPE_NOT_ALLOWED',
        _msg(r, 'نوع الملف .$ext غير مسموح', 'File type .$ext is not allowed'),
        details: {'allowedExtensions': allowed},
      );
    }
    final maxMb = db.settings['maxUploadSizeMb'] as int;
    if (file.bytes.length > maxMb * 1024 * 1024) {
      throw FakeError(
        400,
        'FILE_TOO_LARGE',
        _msg(r, 'حجم الملف يتجاوز $maxMb ميغابايت', 'File exceeds $maxMb MB'),
        details: {'maxUploadSizeMb': maxMb},
      );
    }
    final b = file.bytes;
    bool starts(List<int> sig) =>
        b.length >= sig.length &&
        List.generate(sig.length, (i) => b[i] == sig[i]).every((x) => x);
    final (String mime, bool ok, String conversion) = switch (ext) {
      'pdf' => ('application/pdf', starts([0x25, 0x50, 0x44, 0x46]), 'ready'),
      'png' => ('image/png', starts([0x89, 0x50, 0x4E, 0x47]), 'ready'),
      'jpg' || 'jpeg' => ('image/jpeg', starts([0xFF, 0xD8, 0xFF]), 'ready'),
      'webp' => ('image/webp', starts([0x52, 0x49, 0x46, 0x46]), 'ready'),
      // The real server converts Word → PDF (FR-054). The fake cannot, so the
      // conversion is reported as failed and the viewer explains it.
      'docx' => ('application/pdf', starts([0x50, 0x4B]), 'failed'),
      'doc' => ('application/pdf', starts([0xD0, 0xCF, 0x11, 0xE0]), 'failed'),
      _ => ('application/octet-stream', false, 'failed'),
    };
    if (!ok) {
      throw FakeError(
        400,
        'FILE_TYPE_NOT_ALLOWED',
        _msg(
          r,
          'محتوى الملف لا يطابق امتداده',
          'File content does not match its extension',
        ),
      );
    }
    return (mimeType: mime, conversionStatus: conversion);
  }
}
