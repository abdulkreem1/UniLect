import 'dart:async';

import 'package:dio/dio.dart';

import '../device/device_identity.dart';
import '../storage/token_storage.dart';
import 'api_client.dart';
import 'app_failure.dart';
import 'error_mapper.dart';

/// Emitted when the server says the session is no longer valid (revoked,
/// disabled account, device no longer bound…). The session controller listens
/// and routes the user back to login with an explanation.
class SessionTerminated {
  const SessionTerminated(this.code);
  final String code;
}

/// Adds device / language / bearer headers to every request (FR-009) and
/// transparently refreshes an expired access token once, with a single
/// in-flight refresh shared by concurrent requests.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._tokens,
    required this._device,
    required this._languageCode,
    required this._onSessionTerminated,
  });

  /// The server binds student sessions to this header, including on refresh.
  static const deviceHeader = 'X-Device-ID';

  final Dio _dio;
  final TokenStorage _tokens;
  final DeviceIdentityProvider _device;
  final String Function() _languageCode;
  final void Function(SessionTerminated event) _onSessionTerminated;
  Completer<String?>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final identity = await _device.get();
    options.headers[deviceHeader] = identity.installId;
    options.headers['Accept-Language'] = _languageCode();
    if (options.extra[RequestFlags.skipAuth] != true &&
        !options.headers.containsKey('Authorization')) {
      final tokens = await _tokens.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final failure = mapDioException(err);
    final isAuthCall = options.extra[RequestFlags.skipAuth] == true;
    if (failure is! ApiFailure || isAuthCall) return handler.next(err);

    // An expired (or otherwise unusable) access token: rotate once and retry.
    if (failure.code == ErrorCodes.tokenNotValid &&
        options.extra[RequestFlags.retried] != true) {
      final newToken = await _refresh();
      if (newToken == null) return handler.next(err);
      try {
        options.extra[RequestFlags.retried] = true;
        options.headers['Authorization'] = 'Bearer $newToken';
        return handler.resolve(await _dio.fetch<dynamic>(options));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }

    if (ErrorCodes.sessionTerminating.contains(failure.code) ||
        failure.statusCode == 401) {
      await _terminate(failure.code);
    }
    handler.next(err);
  }

  Future<String?> _refresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = _refreshing = Completer<String?>();
    () async {
      try {
        final tokens = await _tokens.read();
        if (tokens == null) {
          completer.complete(null);
          return;
        }
        // Refresh tokens rotate: replaying an old one revokes the session.
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/refresh/',
          data: {'refresh': tokens.refreshToken},
          options: Options(extra: const {RequestFlags.skipAuth: true}),
        );
        final rotated = StoredTokens.fromApi(response.data!);
        await _tokens.save(rotated);
        completer.complete(rotated.accessToken);
      } on DioException catch (e) {
        final failure = mapDioException(e);
        if (failure is ApiFailure) await _terminate(failure.code);
        completer.complete(null);
      } on Object {
        completer.complete(null);
      } finally {
        _refreshing = null;
      }
    }();
    return completer.future;
  }

  Future<void> _terminate(String code) async {
    await _tokens.clear();
    _onSessionTerminated(SessionTerminated(code));
  }
}
