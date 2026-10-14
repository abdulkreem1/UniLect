import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/academic/data/academic_repository.dart';
import '../features/admin/data/admin_repository.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/content/data/content_repository.dart';
import '../features/content/data/manage_content_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/settings/data/config_repository.dart';
import 'config/app_config.dart';
import 'device/device_identity.dart';
import 'l10n/locale_controller.dart';
import 'network/api_client.dart';
import 'network/auth_interceptor.dart';
import 'network/redacting_log_interceptor.dart';
import 'storage/secure_store.dart';
import 'storage/token_storage.dart';

/// Composition root. Every dependency is a provider so tests can override it.

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStoreProvider)),
);

final deviceIdentityProvider = Provider<DeviceIdentityProvider>(
  (ref) => DeviceIdentityService(ref.watch(secureStoreProvider)),
);

/// Replaces Dio's HTTP transport (tests only).
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Broadcast of server-side session terminations (revoked, device unbound…).
final sessionTerminationsProvider =
    Provider<StreamController<SessionTerminated>>((ref) {
      final controller = StreamController<SessionTerminated>.broadcast();
      ref.onDispose(controller.close);
      return controller;
    });

final apiClientProvider = Provider<ApiClient>((ref) {
  final terminations = ref.watch(sessionTerminationsProvider);
  return buildApiClient(
    config: ref.watch(appConfigProvider),
    tokens: ref.watch(tokenStorageProvider),
    device: ref.watch(deviceIdentityProvider),
    languageCode: () => ref.read(localeControllerProvider).languageCode,
    onSessionTerminated: terminations.add,
    adapter: ref.watch(httpAdapterProvider),
  );
});

/// Wires Dio with the app's interceptor chain. Shared by the provider and by
/// tests so both exercise the exact same networking stack.
ApiClient buildApiClient({
  required AppConfig config,
  required TokenStorage tokens,
  required DeviceIdentityProvider device,
  required String Function() languageCode,
  required void Function(SessionTerminated event) onSessionTerminated,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokens: tokens,
      device: device,
      languageCode: languageCode,
      onSessionTerminated: onSessionTerminated,
    ),
  );
  if (kDebugMode) dio.interceptors.add(RedactingLogInterceptor());
  return ApiClient(dio);
}

// ── Repositories ──

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
    ref.watch(deviceIdentityProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

final academicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(ref.watch(apiClientProvider)),
);

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(apiClientProvider)),
);

final manageContentRepositoryProvider = Provider<ManageContentRepository>(
  (ref) => ManageContentRepository(ref.watch(apiClientProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(apiClientProvider)),
);
