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
import 'package:unilect/features/auth/data/auth_repository.dart';
import 'package:unilect/features/auth/domain/user.dart';
import 'package:unilect/features/devices/domain/device_models.dart';

AppUser user(UserRole role, {bool mustChangePassword = false}) => AppUser(
  id: 'u',
  role: role,
  fullName: 'Test User',
  email: 't@test.dev',
  status: AccountStatus.active,
  createdAt: DateTime(2026),
  mustChangePassword: mustChangePassword,
);

void main() {
  group('Error mapping', () {
    final options = RequestOptions(path: '/x');

    test('maps the API error envelope and its field errors', () {
      final failure = mapDioException(
        DioException.badResponse(
          statusCode: 400,
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 400,
            data: {
              'error': {
                'code': 'validation_error',
                'message': 'Invalid input.',
                'details': {
                  'fields': {
                    'email': ['A user with this email already exists.'],
                  },
                },
              },
            },
          ),
        ),
      );
      expect(
        failure,
        isA<ApiFailure>()
            .having((f) => f.code, 'code', ErrorCodes.validationError)
            .having(
              (f) => f.fields['email'],
              'field',
              'A user with this email already exists.',
            )
            // The specific field message is more useful than "Invalid input.".
            .having(
              (f) => f.message,
              'message',
              'A user with this email already exists.',
            ),
      );
    });

    test('keeps business details (device change token)', () {
      final failure = failureFromResponse(403, {
        'error': {
          'code': 'device_not_bound',
          'message': 'Bound to another device.',
          'details': {
            'device_change_token': 't',
            'device_change_token_expires_in': 900,
            'pending_request': null,
          },
        },
      });
      expect(failure.code, ErrorCodes.deviceNotBound);
      expect(failure.message, 'Bound to another device.');
      final mismatch = DeviceMismatch.fromDetails(
        failure.details,
        now: DateTime.utc(2026),
      );
      expect(mismatch.ticket, 't');
      expect(mismatch.ticketExpiresAt, DateTime.utc(2026, 1, 1, 0, 15));
      expect(mismatch.pendingRequest, isNull);
    });

    test('decodes envelopes returned as bytes (file endpoints)', () {
      final bytes = utf8.encode(
        jsonEncode({
          'error': {'code': 'not_found', 'message': 'Not found.'},
        }),
      );
      expect(failureFromResponse(404, bytes).code, ErrorCodes.notFound);
    });

    test('falls back to http_<status> without an envelope', () {
      expect(failureFromResponse(502, '<html>').code, 'http_502');
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
      expect(guard(out, Routes.resetPassword), isNull);
      expect(guard(out, Routes.changePassword), Routes.login);
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
      expect(guard(student, Routes.changePassword), Routes.studentBrowse);

      expect(guard(library, Routes.adminUsers), Routes.libraryHome);
      expect(guard(library, '/manage/new'), isNull);
      expect(guard(library, '/content/c1'), Routes.libraryHome);

      expect(guard(admin, Routes.libraryHome), Routes.adminHome);
      expect(guard(admin, Routes.adminSettings), isNull);
      expect(guard(admin, Routes.adminLibraries), isNull);
      expect(guard(admin, '/view/c1'), isNull);
    });

    test('a temporary password confines the user to changing it', () {
      final fresh = SignedIn(user(UserRole.admin, mustChangePassword: true));
      expect(guard(fresh, Routes.adminHome), Routes.changePassword);
      expect(guard(fresh, Routes.login), Routes.changePassword);
      expect(guard(fresh, Routes.changePassword), isNull);
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

    test('reads a login/refresh response', () {
      final t = StoredTokens.fromApi({
        'access': 'a',
        'refresh': 'r',
        'token_type': 'Bearer',
        'access_expires_in': 600,
        'refresh_expires_in': 2592000,
      }, now: DateTime.utc(2026));
      expect(t.accessToken, 'a');
      expect(t.refreshToken, 'r');
      expect(t.expiresAt, DateTime.utc(2026, 1, 1, 0, 10));
    });
  });

  test('Paged reads DRF pages', () {
    final p = Paged<int>.fromDrf(
      {
        'count': 3,
        'next': 'http://x/?page=2',
        'previous': null,
        'results': [
          {'v': 1},
          {'v': 2},
        ],
      },
      (j) => j['v'] as int,
      page: 1,
      pageSize: 2,
    );
    expect(p.items, [1, 2]);
    expect(p.hasMore, isTrue);
    expect(
      const Paged(items: [3], page: 2, pageSize: 2, total: 3).hasMore,
      isFalse,
    );
  });

  test('AppUser parses the API user and its initials', () {
    final u = AppUser.fromJson({
      'id': '0b6f',
      'email': 'a@b.c',
      'full_name': 'أحمد خالد',
      'phone': '',
      'role': 'student',
      'student_number': '2023104512',
      'university': 3,
      'university_name': 'جامعة دمشق',
      'library': null,
      'library_name': null,
      'must_change_password': true,
      'date_joined': '2026-09-01T09:00:00Z',
      'active_device': {
        'id': 'd',
        'platform': 'ios',
        'model_name': 'iPhone15,3',
        'status': 'active',
        'bound_at': '2026-09-02T09:00:00Z',
      },
    });
    expect(u.role, UserRole.student);
    expect(u.universityId, '3');
    expect(u.phone, isNull);
    expect(u.mustChangePassword, isTrue);
    expect(u.isActive, isTrue);
    expect(u.boundDevice?.label, 'iOS · iPhone15,3');
    expect(u.initials, 'أ خ');
    expect(user(UserRole.student).initials, 'T U');
  });

  test('ResetLink reads the emailed link', () {
    final link = ResetLink.tryParse(
      ' unilect://app/reset-password?uid=MTIz&token=abc-def ',
    );
    expect(link?.uid, 'MTIz');
    expect(link?.token, 'abc-def');
    expect(ResetLink.tryParse('hello'), isNull);
    expect(ResetLink.tryParse('unilect://app/reset-password?uid=x'), isNull);
  });
}
