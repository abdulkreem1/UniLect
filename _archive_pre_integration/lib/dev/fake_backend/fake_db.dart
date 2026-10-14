import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// In-memory state of the dev fake backend. Mirrors what a real server would
/// persist; everything resets when the app restarts.
class FakeDb {
  final users = <String, FUser>{};
  final sessions = <String, FSession>{}; // by access token
  final tickets = <String, FTicket>{};
  final resetCodes = <String, FResetCode>{}; // by email
  final resetTokens = <String, String>{}; // token -> userId

  /// Structure items stored as JSON maps, keyed by kind (API path name).
  final structure = <String, Map<String, Map<String, dynamic>>>{
    for (final k in structureKinds) k: <String, Map<String, dynamic>>{},
  };

  final content = <String, FContent>{};
  final deviceRequests = <String, Map<String, dynamic>>{};

  /// Unmasked device of each pending request, applied on approval.
  final pendingDevices = <String, Map<String, String>>{};
  final deviceLogs = <Map<String, dynamic>>[];
  final auditLogs = <Map<String, dynamic>>[];
  final notifications = <FNotification>[];
  final reports = <String, Map<String, dynamic>>{};

  final settings = <String, dynamic>{
    'maxUploadSizeMb': 25,
    'allowedExtensions': ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx'],
    'requireContentReview': false,
    'watermarkEnabled': true,
    'screenCaptureProtection': true,
  };

  static const structureKinds = [
    'universities',
    'faculties',
    'years',
    'specializations',
    'subjects',
    'doctors',
    'terms',
    'exam-types',
  ];

  final _random = Random.secure();
  int _seq = 1000;

  String newId(String prefix) => '$prefix-${_seq++}';

  String newToken() =>
      base64Url.encode(List.generate(32, (_) => _random.nextInt(256)));

  String newPublicCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'UL-${List.generate(5, (_) => alphabet[_random.nextInt(alphabet.length)]).join()}';
  }

  String newResetCode() => (100000 + _random.nextInt(900000)).toString();

  Map<String, dynamic>? item(String kind, String? id) =>
      id == null ? null : structure[kind]![id];
}

class FUser {
  FUser({
    required this.id,
    required this.publicCode,
    required this.role,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.studentNumber,
    this.phone,
    this.status = 'active',
    this.scope,
  });

  final String id;
  final String publicCode;
  final String role;
  String fullName;
  String email;
  String? studentNumber;
  String? phone;
  String status;
  Map<String, List<String>>? scope;
  Map<String, String>? boundDevice;
  final DateTime createdAt;
  final favorites = <String>{};
  final followedSubjects = <String>{};

  // Passwords are stored as salted SHA-256 — never in clear text (FR-080).
  late String _salt;
  late String _hash;

  void setPassword(String password) {
    _salt = base64Url.encode(
      List.generate(16, (_) => Random.secure().nextInt(256)),
    );
    _hash = _digest(password);
  }

  bool checkPassword(String password) => _digest(password) == _hash;

  String _digest(String password) =>
      sha256.convert(utf8.encode('$_salt:$password')).toString();

  Map<String, dynamic> toJson({bool admin = false}) => {
    'id': id,
    'publicCode': publicCode,
    'role': role,
    'fullName': fullName,
    'email': email,
    'studentNumber': studentNumber,
    'phone': phone,
    'status': status,
    'scope': scope,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (admin) 'boundDevice': maskDevice(boundDevice),
  };

  Map<String, dynamic> get actor => {'id': id, 'name': fullName, 'role': role};
}

Map<String, dynamic>? maskDevice(Map<String, String>? device) {
  if (device == null) return null;
  final id = device['installId'] ?? '';
  return {
    ...device,
    'installId': id.length <= 4 ? id : '…${id.substring(id.length - 4)}',
  };
}

class FSession {
  FSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.installId,
    required this.accessExpiresAt,
  });

  String accessToken;
  String refreshToken;
  final String userId;
  final String installId;
  DateTime accessExpiresAt;
  bool revoked = false;
}

class FTicket {
  FTicket({
    required this.userId,
    required this.device,
    required this.expiresAt,
  });
  final String userId;
  final Map<String, String> device;
  final DateTime expiresAt;
}

class FResetCode {
  FResetCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
  int attempts = 0;
}

class FFileVersion {
  FFileVersion({
    required this.version,
    required this.bytes,
    required this.originalName,
    required this.mimeType,
    required this.conversionStatus,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  final int version;
  final Uint8List bytes;
  final String originalName;
  final String mimeType;
  final String conversionStatus;
  final DateTime uploadedAt;
  final Map<String, dynamic> uploadedBy;
}

class FContent {
  FContent({
    required this.id,
    required this.type,
    required this.title,
    required this.subjectId,
    required this.status,
    required this.ownerId,
    required this.createdAt,
    this.description,
    this.doctorId,
    this.lectureNumber,
    this.examYear,
    this.termId,
    this.examTypeId,
  }) : updatedAt = createdAt;

  final String id;
  final String type;
  String title;
  String? description;
  String subjectId;
  String? doctorId;
  int? lectureNumber;
  int? examYear;
  String? termId;
  String? examTypeId;
  String status;
  String? reviewNote;
  final String ownerId;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? publishedAt;
  final versions = <FFileVersion>[];

  FFileVersion get current => versions.last;

  Map<String, Object?> metadataSnapshot() => {
    'title': title,
    'description': description,
    'subjectId': subjectId,
    'doctorId': doctorId,
    'lectureNumber': lectureNumber,
    'examYear': examYear,
    'termId': termId,
    'examTypeId': examTypeId,
  };

  void restoreMetadata(Map<String, Object?> m) {
    title = m['title']! as String;
    description = m['description'] as String?;
    subjectId = m['subjectId']! as String;
    doctorId = m['doctorId'] as String?;
    lectureNumber = m['lectureNumber'] as int?;
    examYear = m['examYear'] as int?;
    termId = m['termId'] as String?;
    examTypeId = m['examTypeId'] as String?;
  }
}

class FNotification {
  FNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.data = const {},
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final Map<String, String> data;
  bool isRead = false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'isRead': isRead,
    'data': data,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
