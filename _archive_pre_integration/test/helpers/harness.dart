import 'package:unilect/core/config/app_config.dart';
import 'package:unilect/core/device/device_identity.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/core/network/auth_interceptor.dart';
import 'package:unilect/core/providers.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/core/storage/token_storage.dart';
import 'package:unilect/dev/fake_backend/fake_backend.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/features/auth/data/auth_repository.dart';

class FixedDevice implements DeviceIdentityProvider {
  FixedDevice(this.installId);
  final String installId;

  @override
  Future<DeviceIdentity> get() async =>
      DeviceIdentity(installId: installId, platform: 'android', model: 'Test');
}

/// Mutable clock so tests can expire tokens.
class TestClock {
  DateTime value = DateTime.utc(2026, 10, 1, 9);
  DateTime call() => value;
  void advance(Duration d) => value = value.add(d);
}

/// One simulated app installation talking to a shared [FakeBackend].
class TestDevice {
  TestDevice(this.backend, String installId) : device = FixedDevice(installId) {
    tokens = TokenStorage(MemorySecureStore());
    api = buildApiClient(
      config: const AppConfig(
        apiBaseUrl: 'https://test.invalid/api/v1',
        useFakeBackend: true,
      ),
      tokens: tokens,
      device: device,
      languageCode: () => 'en',
      onSessionTerminated: terminations.add,
      fakeBackend: backend,
      fakeLatency: Duration.zero,
    );
    auth = AuthRepository(api, tokens, device);
  }

  final FakeBackend backend;
  final FixedDevice device;
  late final TokenStorage tokens;
  late final ApiClient api;
  late final AuthRepository auth;
  final terminations = <SessionTerminated>[];

  Future<LoginOutcome> login(String email) =>
      auth.login(email: email, password: DevAccounts.password);
}

({FakeBackend backend, TestClock clock}) newBackend() {
  final clock = TestClock();
  return (
    backend: FakeBackend(
      db: seededFakeDb(now: clock.value),
      clock: clock.call,
    ),
    clock: clock,
  );
}
