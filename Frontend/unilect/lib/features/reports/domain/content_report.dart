import '../../../core/models/json.dart';

enum ReportReason {
  wrongFile('wrong'),
  duplicate('duplicate'),
  inappropriate('inappropriate'),
  other('other');

  const ReportReason(this.apiValue);

  final String apiValue;

  static ReportReason fromApi(Object? value) =>
      values.firstWhere((r) => r.apiValue == value, orElse: () => other);
}

enum ReportStatus {
  open('open'),
  inReview('in_review'),
  resolved('resolved'),
  dismissed('rejected');

  const ReportStatus(this.apiValue);

  final String apiValue;

  static ReportStatus fromApi(Object? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => open);

  /// Transitions the server allows (FR-074); resolved and dismissed are final.
  List<ReportStatus> get next => switch (this) {
    open => const [inReview, resolved, dismissed],
    inReview => const [resolved, dismissed],
    resolved || dismissed => const [],
  };
}

/// A status change or note on a report.
class ReportHistoryEntry {
  const ReportHistoryEntry({
    required this.status,
    required this.actor,
    required this.at,
    this.note,
  });

  factory ReportHistoryEntry.fromJson(Json json) => ReportHistoryEntry(
    status: ReportStatus.fromApi(json['to_status']),
    actor: json['actor'] as String? ?? '—',
    at: parseDate(json['created_at']),
    note: textOrNull(json['note']),
  );

  final ReportStatus status;

  /// Email of the administrator.
  final String actor;
  final DateTime at;
  final String? note;
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.contentId,
    required this.contentTitle,
    required this.reason,
    required this.status,
    required this.reporter,
    required this.createdAt,
    this.note,
    this.history = const [],
  });

  factory ContentReport.fromJson(Json json) => ContentReport(
    id: idOf(json['id']),
    contentId: idOf(json['content']),
    contentTitle: json['content_title'] as String? ?? '',
    reason: ReportReason.fromApi(json['reason']),
    status: ReportStatus.fromApi(json['status']),
    reporter: json['reporter_email'] as String? ?? '—',
    createdAt: parseDate(json['created_at']),
    note: textOrNull(json['message']),
    history: parseList(json['actions'], ReportHistoryEntry.fromJson),
  );

  final String id;
  final String contentId;
  final String contentTitle;
  final ReportReason reason;
  final ReportStatus status;

  /// Email of the reporting student.
  final String reporter;
  final DateTime createdAt;
  final String? note;
  final List<ReportHistoryEntry> history;
}
