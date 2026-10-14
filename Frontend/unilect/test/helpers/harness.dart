import 'dart:io';

import 'package:unilect/core/config/app_config.dart';
import 'package:unilect/core/device/device_identity.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/core/network/auth_interceptor.dart';
import 'package:unilect/core/providers.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/core/storage/token_storage.dart';
import 'package:unilect/features/academic/data/academic_repository.dart';
import 'package:unilect/features/admin/data/admin_repository.dart';
import 'package:unilect/features/auth/data/auth_repository.dart';
import 'package:unilect/features/content/data/content_repository.dart';
import 'package:unilect/features/content/data/manage_content_repository.dart';
import 'package:unilect/features/notifications/data/notifications_repository.dart';
import 'package:unilect/features/profile/data/profile_repository.dart';

/// Accounts created by the backend's `manage.py seed_demo`.
abstract final class DemoAccounts {
  static const password = 'UniLect#2026';
  static const admin = 'admin@unilect.test';
  static const library = 'library@unilect.test';
  static const libraryAleppo = 'library.aleppo@unilect.test';
  static const student = 'student@unilect.test';
  static const studentOtherDevice = 'student2@unilect.test';
  static const disabledStudent = 'disabled@unilect.test';
}

/// Base URL of a running, seeded backend for the live API tests, e.g.
/// `UNILECT_API=http://127.0.0.1:8001/api/v1`. Null skips them.
String? get liveApiBaseUrl {
  final url = Platform.environment['UNILECT_API'];
  return (url == null || url.isEmpty) ? null : url;
}

class FixedDevice implements DeviceIdentityProvider {
  FixedDevice(this.installId);
  final String installId;

  @override
  Future<DeviceIdentity> get() async =>
      DeviceIdentity(installId: installId, platform: 'android', model: 'Test');
}

/// One simulated app installation talking to the live backend: its own
/// install ID, token storage and the app's real networking stack.
class TestDevice {
  TestDevice(String baseUrl, String installId)
    : device = FixedDevice(installId) {
    tokens = TokenStorage(MemorySecureStore());
    api = buildApiClient(
      config: AppConfig(apiBaseUrl: baseUrl),
      tokens: tokens,
      device: device,
      languageCode: () => 'en',
      onSessionTerminated: terminations.add,
    );
    auth = AuthRepository(api, tokens, device);
  }

  final FixedDevice device;
  late final TokenStorage tokens;
  late final ApiClient api;
  late final AuthRepository auth;
  final terminations = <SessionTerminated>[];

  AcademicRepository get academic => AcademicRepository(api);
  ContentRepository get content => ContentRepository(api);
  ManageContentRepository get manage => ManageContentRepository(api);
  AdminRepository get admin => AdminRepository(api);
  NotificationsRepository get notifications => NotificationsRepository(api);
  ProfileRepository get profile => ProfileRepository(api);

  Future<LoginOutcome> login(
    String email, {
    String password = DemoAccounts.password,
  }) => auth.login(email: email, password: password);
}
