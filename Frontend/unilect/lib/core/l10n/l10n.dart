import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../features/auth/domain/user.dart';
import '../../features/content/domain/content.dart';
import '../../features/devices/domain/device_models.dart';
import '../../features/reports/domain/content_report.dart';
import '../../l10n/gen/app_localizations.dart';
import '../network/app_failure.dart';

export '../../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get _locale => Localizations.localeOf(this).languageCode;

  String formatDate(DateTime d) => DateFormat.yMMMd(_locale).format(d);

  String formatDateTime(DateTime d) =>
      DateFormat.yMMMd(_locale).add_jm().format(d);

  /// "منذ 3 أيام" style for recent dates, absolute date otherwise.
  String formatRelative(DateTime d) {
    final diff = DateTime.now().difference(d);
    final ar = _locale == 'ar';
    if (diff.inMinutes < 1) return ar ? 'الآن' : 'just now';
    if (diff.inMinutes < 60) {
      return ar ? 'منذ ${diff.inMinutes} د' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return ar ? 'منذ ${diff.inHours} س' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return ar ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    }
    return formatDate(d);
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// User-facing message for any failure. Server messages (already localized
  /// via `Accept-Language`) win; otherwise a client message per code.
  String failureMessage(Object error) {
    final l = l10n;
    return switch (error) {
      NetworkFailure() => l.errorNetwork,
      TimeoutFailure() => l.errorTimeout,
      ApiFailure(:final message?) when message.isNotEmpty => message,
      ApiFailure(:final code) => switch (code) {
        ErrorCodes.invalidCredentials => l.invalidCredentials,
        ErrorCodes.accountDisabled => l.accountDisabled,
        ErrorCodes.permissionDenied ||
        ErrorCodes.libraryOnly => l.errorForbidden,
        ErrorCodes.notFound => l.errorNotFound,
        ErrorCodes.validationError => l.errorValidation,
        ErrorCodes.throttled ||
        ErrorCodes.tooManyFailedAttempts => l.errorRateLimited,
        ErrorCodes.sessionRevoked ||
        ErrorCodes.tokenNotValid => l.sessionEndedRevoked,
        ErrorCodes.deviceMismatch => l.sessionEndedDevice,
        _ => l.errorUnknown,
      },
      _ => l.errorUnknown,
    };
  }
}

/// Localized labels for domain enums.
extension DomainLabels on AppLocalizations {
  String roleLabel(UserRole r) => switch (r) {
    UserRole.student => roleStudent,
    UserRole.library => roleLibrary,
    UserRole.admin => roleAdmin,
  };

  String contentStatusLabel(ContentStatus s) => switch (s) {
    ContentStatus.draft => statusDraft,
    ContentStatus.pendingReview => statusPendingReview,
    ContentStatus.published => statusPublished,
    ContentStatus.archived => statusArchived,
  };

  String contentTypeLabel(ContentType t) => switch (t) {
    ContentType.lecture => typeLecture,
    ContentType.exam => typeExam,
  };

  String deviceStatusLabel(DeviceChangeStatus s) => switch (s) {
    DeviceChangeStatus.pending => statusPending,
    DeviceChangeStatus.approved => statusApproved,
    DeviceChangeStatus.rejected => statusRejected,
    DeviceChangeStatus.cancelled => statusCancelled,
  };

  String deviceLogLabel(DeviceLogAction a) => switch (a) {
    DeviceLogAction.bound => logBound,
    DeviceLogAction.changeRequested => logChangeRequested,
    DeviceLogAction.approved => logApproved,
    DeviceLogAction.rejected => logRejected,
    DeviceLogAction.cancelled => logCancelled,
    DeviceLogAction.unbound => logUnbound,
  };

  String reportReasonLabel(ReportReason r) => switch (r) {
    ReportReason.wrongFile => reasonWrongFile,
    ReportReason.duplicate => reasonDuplicate,
    ReportReason.inappropriate => reasonInappropriate,
    ReportReason.other => reasonOther,
  };

  String reportStatusLabel(ReportStatus s) => switch (s) {
    ReportStatus.open => reportOpen,
    ReportStatus.inReview => reportInReview,
    ReportStatus.resolved => reportResolved,
    ReportStatus.dismissed => reportDismissed,
  };

  /// Audit trail category (`AuditCategories`).
  String auditCategoryLabel(String category) => switch (category) {
    'account' => auditAccount,
    'auth' => auditAuth,
    'device' => entityDevice,
    'catalog' => auditCatalog,
    'library' => auditLibrary,
    'content' => entityContent,
    'report' => entityReport,
    'settings' => entitySettings,
    'security' => auditSecurity,
    _ => category,
  };
}
