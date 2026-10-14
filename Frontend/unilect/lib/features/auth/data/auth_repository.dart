import '../../../core/device/device_identity.dart';
import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/token_storage.dart';
import '../../devices/domain/device_models.dart';
import '../domain/user.dart';

sealed class LoginOutcome {
  const LoginOutcome();
}

class LoggedIn extends LoginOutcome {
  const LoggedIn(this.user);
  final AppUser user;
}

/// The student account is bound to another device (FR-010).
class DeviceBlocked extends LoginOutcome {
  const DeviceBlocked(this.mismatch);
  final DeviceMismatch mismatch;
}

/// uid + token from the emailed password-reset link
/// (`unilect://app/reset-password?uid=…&token=…`).
class ResetLink {
  const ResetLink({required this.uid, required this.token});

  /// Accepts the full link (or any URL carrying `uid` and `token`).
  static ResetLink? tryParse(String text) {
    final uri = Uri.tryParse(text.trim());
    final uid = uri?.queryParameters['uid'];
    final token = uri?.queryParameters['token'];
    if (uid == null || uid.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return ResetLink(uid: uid, token: token);
  }

  final String uid;
  final String token;
}

class AuthRepository {
  AuthRepository(this._api, this._tokens, this._device);

  final ApiClient _api;
  final TokenStorage _tokens;
  final DeviceIdentityProvider _device;

  Future<bool> hasSession() async => await _tokens.read() != null;

  /// Every role sends the device; the server only binds it for students.
  Future<LoginOutcome> login({
    required String email,
    required String password,
  }) async {
    final device = await _device.get();
    try {
      final json = await _api.post<Json>(
        '/auth/login/',
        authenticated: false,
        body: {
          'email': email.trim(),
          'password': password,
          'device': device.toJson(),
        },
      );
      await _tokens.save(StoredTokens.fromApi(json));
      return LoggedIn(AppUser.fromJson(json['user'] as Json));
    } on ApiFailure catch (f) {
      if (f.code == ErrorCodes.deviceNotBound) {
        return DeviceBlocked(DeviceMismatch.fromDetails(f.details));
      }
      rethrow;
    }
  }

  Future<AppUser> fetchMe() async =>
      AppUser.fromJson(await _api.get<Json>('/me/'));

  /// Revokes the session server-side when possible; local tokens are always
  /// wiped so protected screens become unreachable (FR-003).
  Future<void> logout() async {
    try {
      if (await _tokens.read() != null) await _api.post<void>('/auth/logout/');
    } on AppFailure {
      // Session may already be invalid; local wipe below is what matters.
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> clearLocalSession() => _tokens.clear();

  /// Always accepted (no account enumeration); the server emails a one-time
  /// link valid for one hour.
  Future<void> requestPasswordReset(String email) => _api.post<void>(
    '/auth/password/reset/',
    authenticated: false,
    body: {'email': email.trim()},
  );

  /// Sets the new password and revokes every session of the account.
  Future<void> confirmPasswordReset({
    required ResetLink link,
    required String newPassword,
  }) => _api.post<void>(
    '/auth/password/reset/confirm/',
    authenticated: false,
    body: {'uid': link.uid, 'token': link.token, 'new_password': newPassword},
  );

  /// Filed from the NEW device with the restricted token returned by the
  /// `device_not_bound` login refusal (FR-011).
  Future<StudentDeviceRequest> submitDeviceChangeRequest({
    required String ticket,
    String? reason,
  }) async => StudentDeviceRequest.fromJson(
    await _api.post<Json>(
      '/auth/device-change-requests/',
      authenticated: false,
      headers: {'Authorization': 'Bearer $ticket'},
      body: {'reason': reason?.trim() ?? ''},
    ),
  );
}
