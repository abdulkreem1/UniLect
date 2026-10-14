import '../../../core/models/json.dart';
import '../../auth/domain/user.dart';

enum DeviceChangeStatus { pending, approved, rejected, cancelled }

/// A device-change request as reviewed by an administrator (FR-012, FR-067).
class DeviceChangeRequest {
  const DeviceChangeRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.status,
    required this.newDevice,
    required this.createdAt,
    this.userEmail,
    this.studentNumber,
    this.reason,
    this.oldDevice,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
  });

  factory DeviceChangeRequest.fromJson(Json json) => DeviceChangeRequest(
    id: idOf(json['id']),
    userId: idOf(json['student']),
    userName: json['student_name'] as String? ?? '',
    userEmail: json['student_email'] as String?,
    status: enumByName(
      DeviceChangeStatus.values,
      json['status'],
      DeviceChangeStatus.pending,
    ),
    newDevice: DeviceInfo(
      platform: json['new_platform'] as String? ?? 'android',
      model: textOrNull(json['new_model_name']),
    ),
    createdAt: parseDate(json['created_at']),
    studentNumber: textOrNull(json['student_number']),
    reason: textOrNull(json['reason']),
    oldDevice: json['current_device'] == null
        ? null
        : DeviceInfo.fromJson(json['current_device'] as Json),
    decidedAt: parseDateOrNull(json['decided_at']),
    decidedBy: json['decided_by'] == null
        ? null
        : ActorRef(
            id: idOf(json['decided_by']),
            name: json['decided_by_email'] as String? ?? '',
          ),
    decisionNote: textOrNull(json['decision_note']),
  );

  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final DeviceChangeStatus status;
  final DeviceInfo newDevice;
  final DateTime createdAt;
  final String? studentNumber;
  final String? reason;
  final DeviceInfo? oldDevice;
  final DateTime? decidedAt;
  final ActorRef? decidedBy;
  final String? decisionNote;
}

/// The student's own view of a request filed from a new device (FR-011).
class StudentDeviceRequest {
  const StudentDeviceRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    this.decisionNote,
  });

  factory StudentDeviceRequest.fromJson(Json json) => StudentDeviceRequest(
    id: idOf(json['id']),
    status: enumByName(
      DeviceChangeStatus.values,
      json['status'],
      DeviceChangeStatus.pending,
    ),
    createdAt: parseDate(json['created_at']),
    decisionNote: textOrNull(json['decision_note']),
  );

  final String id;
  final DeviceChangeStatus status;
  final DateTime createdAt;
  final String? decisionNote;
}

enum DeviceLogAction {
  bound,
  changeRequested,
  approved,
  rejected,
  cancelled,
  unbound,
}

/// One device event from the audit trail (`admin/audit-logs/?category=device`,
/// FR-015).
class DeviceLogEntry {
  const DeviceLogEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    required this.subject,
    this.actor,
    this.platform,
    this.note,
  });

  factory DeviceLogEntry.fromAudit(Json json) {
    final metadata = json['metadata'] as Json? ?? const {};
    return DeviceLogEntry(
      id: idOf(json['id']),
      action: switch (json['action']) {
        'device.bound' => DeviceLogAction.bound,
        'device.change_requested' => DeviceLogAction.changeRequested,
        'device.change_approved' => DeviceLogAction.approved,
        'device.change_rejected' => DeviceLogAction.rejected,
        'device.change_cancelled' => DeviceLogAction.cancelled,
        _ => DeviceLogAction.unbound, // device.reset, device.released_*
      },
      createdAt: parseDate(json['created_at']),
      subject:
          metadata['student'] as String? ??
          json['target_repr'] as String? ??
          '',
      actor: textOrNull(json['actor_repr']),
      platform: (metadata['platform'] ?? metadata['new_platform']) as String?,
      note: textOrNull(metadata['note']),
    );
  }

  final String id;
  final DeviceLogAction action;
  final DateTime createdAt;

  /// The student concerned (email), as recorded by the server.
  final String subject;
  final String? note;

  /// Who performed the action (email), when recorded.
  final String? actor;
  final String? platform;
}

/// Payload of a `device_not_bound` login refusal (FR-010).
class DeviceMismatch {
  const DeviceMismatch({
    required this.ticket,
    required this.ticketExpiresAt,
    this.pendingRequest,
  });

  /// From `error.details`: `device_change_token`,
  /// `device_change_token_expires_in` and `pending_request {id, created_at}`.
  factory DeviceMismatch.fromDetails(Json details, {DateTime? now}) {
    final pending = details['pending_request'] as Json?;
    return DeviceMismatch(
      ticket: details['device_change_token'] as String,
      ticketExpiresAt: (now ?? DateTime.now()).add(
        Duration(
          seconds: details['device_change_token_expires_in'] as int? ?? 0,
        ),
      ),
      pendingRequest: pending == null
          ? null
          : StudentDeviceRequest(
              id: idOf(pending['id']),
              status: DeviceChangeStatus.pending,
              createdAt: parseDate(pending['created_at']),
            ),
    );
  }

  /// Restricted token: only accepted by `auth/device-change-requests/`, and
  /// only from this device.
  final String ticket;
  final DateTime ticketExpiresAt;
  final StudentDeviceRequest? pendingRequest;
}
