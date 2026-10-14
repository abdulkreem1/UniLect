import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/user.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// Only the fields the role may edit are sent (FR-007): students `phone`;
  /// library and admin accounts also `full_name`. Anything else is refused
  /// by the server with a field error.
  Future<AppUser> update({
    required UserRole role,
    String? fullName,
    String? phone,
  }) async {
    final json = await _api.patch<Json>(
      '/me/',
      body: {
        if (role != UserRole.student && fullName != null)
          'full_name': fullName.trim(),
        'phone': phone?.trim() ?? '',
      },
    );
    return AppUser.fromJson(json);
  }

  /// Ends the user's other sessions; the current one stays valid.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.post<void>(
    '/auth/password/change/',
    body: {'current_password': currentPassword, 'new_password': newPassword},
  );
}
