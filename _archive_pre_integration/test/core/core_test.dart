import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/app/router.dart';
import 'package:unilect/app/routes.dart';
import 'package:unilect/core/models/json.dart';
import 'package:unilect/core/network/app_failure.dart';
import 'package:unilect/core/network/error_mapper.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/core/storage/token_storage.dart';
import 'package:unilect/features/auth/application/session_controller.dart';
import 'package:unilect/features/auth/domain/user.dart';

AppUser user(UserRole role) => AppUser(
  id: 'u',
  publicCode: 'UL-1',
  role: role,
  fullName: 'Test User',
  email: 't@test.dev',
  status: AccountStatus.active,
  createdAt: DateTime(2026),
);

void main() {
  group('Error mapping', () {
    final options = RequestOptions(path: '/x');

    test('maps the contract error envelope to ApiFailure', () {
      final failure = mapDioException(
        DioException.badResponse(
          statusCode: 400,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 400,
            data: {
              'error': {
                'code': 'VALIDATION_FAILED',
                'message': 'Fix it',
                'fields': {'title': 'required'},
              },
            },
          ),
        ),
      );
      expect(
        failure,
        isA<ApiFailure>()
            .having((f) => f.code, 'code', ErrorCodes.validationFailed)
            .having((f) => f.fields['title'], 'field', 'required')
            .having((f) => f.message, 'message', 'Fix it'),
      );
    });

    test('decodes envelopes returned as bytes (file endpoints)', () {
      final bytes = utf8.encode(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'gone'},
        }),
      );
      final failure = failureFromResponse(404, bytes);
      expect(failure.code, ErrorCodes.notFound);
    });

    test('falls back to HTTP_<status> without an envelope', () {
      expect(failureFromResponse(502, '<html>').code, 'HTTP_502');
    });

    test('maps transport errors', () {
      expect(
        mapDioException(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        ),
        isA<NetworkFailure>(),
      );
      expect(
        mapDioException(
          DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isA<TimeoutFailure>(),
      );
    });
  });

  group('Route guard (FR-003, FR-006)', () {
    test('signed-out users only reach public routes', () {
      const out = SignedOut();
      expect(guard(out, Routes.studentBrowse), Routes.login);
      expect(guard(out, Routes.adminHome), Routes.login);
      expect(guard(out, '/content/c1'), Routes.login);
      expect(guard(out, Routes.login), isNull);
      expect(guard(out, Routes.forgotPassword), isNull);
    });

    test('loading sessions stay on the splash screen', () {
      expect(
        guard(const SessionLoading(), Routes.studentBrowse),
        Routes.splash,
      );
      expect(guard(const SessionLoading(), Routes.splash), isNull);
    });

    test('each role is confined to its own area', () {
      final student = SignedIn(user(UserRole.student));
      final library = SignedIn(user(UserRole.library));
      final admin = SignedIn(user(UserRole.admin));

      expect(guard(student, Routes.login), Routes.studentBrowse);
      expect(guard(student, Routes.adminHome), Routes.studentBrowse);
      expect(guard(student, '/manage/new'), Routes.studentBrowse);
      expect(guard(student, '/content/c1'), isNull);

      expect(guard(library, Routes.adminUsers), Routes.libraryHome);
      expect(guard(library, '/manage/new'), isNull);
      expect(guard(library, '/content/c1'), Routes.libraryHome);

      expect(guard(admin, Routes.libraryHome), Routes.adminHome);
      expect(guard(admin, Routes.adminSettings), isNull);
      expect(guard(admin, '/view/c1'), isNull);
    });
  });

  group('Token storage', () {
    test('persists to secure storage and survives a new instance', () async {
      final store = MemorySecureStore();
      final tokens = StoredTokens(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.utc(2030),
      );
      await TokenStorage(store).save(tokens);
      final restored = await TokenStorage(store).read();
      expect(restored?.refreshToken, 'r');

      await TokenStorage(store).clear();
      expect(await TokenStorage(store).read(), isNull);
    });

    test('ignores corrupted values', () async {
      final store = MemorySecureStore()..values['auth.tokens.v1'] = '{bad';
      expect(await TokenStorage(store).read(), isNull);
    });
  });

  test('Paged.hasMore', () {
    const p = Paged(items: [1, 2], page: 1, pageSize: 2, total: 3);
    expect(p.hasMore, isTrue);
    expect(
      const Paged(items: [3], page: 2, pageSize: 2, total: 3).hasMore,
      isFalse,
    );
  });

  test('AppUser.initials handles Arabic and single names', () {
    expect(user(UserRole.student).initials, 'T U');
    final ar = AppUser(
      id: 'x',
      publicCode: 'p',
      role: UserRole.student,
      fullName: 'أحمد خالد',
      email: 'a@b.c',
      status: AccountStatus.active,
      createdAt: DateTime(2026),
    );
    expect(ar.initials, 'أ خ');
  });
}
