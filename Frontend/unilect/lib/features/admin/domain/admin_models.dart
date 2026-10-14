import '../../../core/models/json.dart';
import '../../content/domain/content.dart';

/// FR-064 summary (`admin/dashboard/`).
class AdminDashboard {
  const AdminDashboard({
    required this.students,
    required this.libraries,
    required this.admins,
    required this.disabledUsers,
    required this.content,
    required this.pendingDeviceRequests,
    required this.pendingReviews,
    required this.openReports,
  });

  factory AdminDashboard.fromJson(Json json) {
    final accounts = json['accounts'] as Json;
    final pending = json['pending_actions'] as Json;
    return AdminDashboard(
      students: accounts['student'] as int? ?? 0,
      libraries: accounts['library'] as int? ?? 0,
      admins: accounts['admin'] as int? ?? 0,
      disabledUsers: accounts['inactive'] as int? ?? 0,
      content: ContentStats.fromJson(json['content'] as Json),
      pendingDeviceRequests: pending['device_change_requests'] as int? ?? 0,
      pendingReviews: pending['content_pending_review'] as int? ?? 0,
      openReports: pending['open_reports'] as int? ?? 0,
    );
  }

  final int students;
  final int libraries;
  final int admins;
  final int disabledUsers;
  final ContentStats content;
  final int pendingDeviceRequests;
  final int pendingReviews;
  final int openReports;
}

/// Audit trail categories (`admin/audit-logs/?category=`).
abstract final class AuditCategories {
  static const all = [
    'account',
    'auth',
    'device',
    'catalog',
    'library',
    'content',
    'report',
    'settings',
    'security',
  ];
}

/// One append-only audit entry (FR-068).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.category,
    required this.entityLabel,
    required this.createdAt,
    this.actor,
    this.entityId,
  });

  factory AuditLogEntry.fromJson(Json json) => AuditLogEntry(
    id: idOf(json['id']),
    action: json['action'] as String,
    category: json['category'] as String,
    actor: textOrNull(json['actor_repr']),
    entityId: textOrNull(json['target_id']),
    entityLabel: textOrNull(json['target_repr']) ?? json['action'] as String,
    createdAt: parseDate(json['created_at']),
  );

  final String id;

  /// Stable action name, e.g. `content.published`.
  final String action;
  final String category;

  /// Email of the actor; null for system or anonymous actions.
  final String? actor;
  final String? entityId;
  final String entityLabel;
  final DateTime createdAt;
}
