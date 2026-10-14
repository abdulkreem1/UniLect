/// Typed failure surfaced to the presentation layer. Every networking error is
/// mapped to one of these so screens never deal with Dio types.
sealed class AppFailure implements Exception {
  const AppFailure({this.message});

  /// Server-provided, already localized message (may be null).
  final String? message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
}

/// A business/API error with a stable machine-readable [code]
/// (see "Errors" in the backend's `docs/02-api-reference.md`).
class ApiFailure extends AppFailure {
  const ApiFailure({
    required this.statusCode,
    required this.code,
    super.message,
    this.fields = const {},
    this.details = const {},
  });

  final int statusCode;
  final String code;

  /// First validation message per field, keyed by the API field name
  /// (`email`, `student_number`, …). From `details.fields`.
  final Map<String, String> fields;
  final Map<String, dynamic> details;

  @override
  String toString() => 'ApiFailure($statusCode, $code)';
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([this.cause]);
  final Object? cause;

  @override
  String toString() => 'UnknownFailure($cause)';
}

/// `error.code` values defined by the API. Clients branch on these, never on
/// the (localized) message.
abstract final class ErrorCodes {
  // 400
  static const validationError = 'validation_error';
  static const fileRejected = 'file_rejected';
  static const incompleteContent = 'incomplete_content';
  static const invalidCurrentPassword = 'invalid_current_password';
  static const invalidResetToken = 'invalid_reset_token';
  // 401
  static const notAuthenticated = 'not_authenticated';
  static const tokenNotValid = 'token_not_valid';
  static const sessionRevoked = 'session_revoked';
  static const invalidCredentials = 'invalid_credentials';
  // 401 (existing session) / 403 (login)
  static const accountDisabled = 'account_disabled';
  // 403
  static const permissionDenied = 'permission_denied';
  static const deviceMismatch = 'device_mismatch';
  static const deviceNotBound = 'device_not_bound';
  static const passwordChangeRequired = 'password_change_required';
  static const libraryOnly = 'library_only';
  // 404
  static const notFound = 'not_found';
  // 409
  static const invalidTransition = 'invalid_transition';
  static const protectedItem = 'protected';
  static const requestAlreadyPending = 'request_already_pending';
  static const reportAlreadyOpen = 'report_already_open';
  // 429
  static const throttled = 'throttled';
  static const tooManyFailedAttempts = 'too_many_failed_attempts';

  /// Codes that mean the current session can no longer be used.
  static const sessionTerminating = {
    sessionRevoked,
    accountDisabled,
    deviceMismatch,
  };
}
