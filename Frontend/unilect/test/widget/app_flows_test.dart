import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/network/auth_interceptor.dart';

import '../helpers/app_harness.dart';
import '../helpers/harness.dart';
import '../helpers/stub_backend.dart';

StubBackend studentBackend({bool mustChangePassword = false}) {
  final b = StubBackend()
    ..json(
      'POST',
      '/auth/login/',
      loginResponse(
        userJson(
          role: 'student',
          studentNumber: '2023104512',
          university: 1,
          mustChangePassword: mustChangePassword,
        ),
      ),
    )
    ..json('POST', '/auth/logout/', null, status: 204)
    ..json('GET', '/catalog/universities/', page([ref(1, 'جامعة دمشق')]))
    ..json(
      'GET',
      '/catalog/faculties/',
      page([
        {'id': 10, 'name': 'كلية الهندسة المعلوماتية', 'university': 1},
      ]),
    )
    ..json(
      'GET',
      '/catalog/levels/',
      page([
        {'id': 100, 'name': 'السنة الأولى', 'number': 1, 'faculty': 10},
      ]),
    )
    ..json('GET', '/catalog/specializations/', page(const []))
    ..json(
      'GET',
      '/catalog/courses/',
      page([
        {
          'id': 1000,
          'name': 'برمجة 1',
          'code': 'ITE101',
          'description': '',
          'university': 1,
          'faculty': 10,
          'level': 100,
          'semester': null,
          'specializations': <int>[],
        },
      ]),
    )
    ..json('GET', '/catalog/courses/1000/instructors/', [
      {'id': 50, 'full_name': 'سامر الخطيب', 'title': 'د.'},
    ])
    ..json('GET', '/me/followed-courses/', page(const []))
    ..json('GET', '/me/favorites/', page(const []))
    ..on('GET', '/catalog/contents/', (r) {
      final kind = r.queryParameters['kind'];
      return StubResponse(
        200,
        page([
          if (kind == 'lecture') ...[
            catalogContent(
              id: 'c1',
              title: 'مقدمة في البرمجة والخوارزميات',
              lectureNumber: 1,
            ),
            catalogContent(
              id: 'c2',
              title: 'المتحولات وأنماط البيانات',
              lectureNumber: 2,
            ),
          ],
        ]),
      );
    })
    ..json(
      'GET',
      '/catalog/contents/c1/',
      catalogContent(
        id: 'c1',
        title: 'مقدمة في البرمجة والخوارزميات',
        lectureNumber: 1,
      ),
    );
  stubShell(b);
  return b;
}

void main() {
  group('Login (FR-002)', () {
    testWidgets('validates fields before calling the server', (tester) async {
      final backend = await pumpUniLect(tester);
      expect(find.text(ar.loginWelcome), findsOneWidget);

      await tester.tap(find.text(ar.signIn));
      await tester.pumpAndSettle();
      expect(find.text(ar.fieldRequired), findsNWidgets(2));

      await tester.enterText(
        find.widgetWithText(TextFormField, ar.email),
        'not-an-email',
      );
      await tester.tap(find.text(ar.signIn));
      await tester.pumpAndSettle();
      expect(find.text(ar.emailInvalid), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('sends the device and shows the server message on failure', (
      tester,
    ) async {
      final backend = StubBackend()
        ..json(
          'POST',
          '/auth/login/',
          apiError(
            'invalid_credentials',
            'البريد الإلكتروني/الرقم الجامعي أو كلمة المرور غير صحيحة.',
          ),
          status: 401,
        );
      await pumpUniLect(tester, backend: backend);
      await signIn(tester, DemoAccounts.student, password: 'wrong-password');

      expect(
        find.text('البريد الإلكتروني/الرقم الجامعي أو كلمة المرور غير صحيحة.'),
        findsOneWidget,
      );
      final login = backend.sent('/auth/login/').single;
      expect(login.data, {
        'email': DemoAccounts.student,
        'password': 'wrong-password',
        'device': {
          'installation_id': testInstallId,
          'platform': 'android',
          'model': 'Test',
        },
      });
      expect(login.headers[AuthInterceptor.deviceHeader], testInstallId);
      expect(login.headers['Accept-Language'], 'ar');
    });
  });

  testWidgets('student browses university → faculty → year → subject', (
    tester,
  ) async {
    final backend = await pumpUniLect(tester, backend: studentBackend());
    await signIn(tester, DemoAccounts.student);

    expect(find.text(ar.greeting('أحمد')), findsOneWidget);
    await tester.tap(find.text('جامعة دمشق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كلية الهندسة المعلوماتية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السنة الأولى'));
    await tester.pumpAndSettle();
    expect(find.text('برمجة 1'), findsOneWidget);

    await tester.tap(find.text('برمجة 1'));
    await tester.pumpAndSettle();
    expect(find.text('د. سامر الخطيب'), findsOneWidget);

    await tester.tap(find.text('د. سامر الخطيب'));
    await tester.pumpAndSettle();
    expect(find.text('مقدمة في البرمجة والخوارزميات'), findsOneWidget);
    expect(find.text(ar.lecturesCount(2)), findsOneWidget);
    final lectures = backend.sent('/catalog/contents/').last;
    expect(lectures.queryParameters, containsPair('course', '1000'));
    expect(lectures.queryParameters, containsPair('instructor', '50'));
    expect(lectures.queryParameters, containsPair('kind', 'lecture'));

    await tester.tap(find.text('مقدمة في البرمجة والخوارزميات'));
    await tester.pumpAndSettle();
    expect(find.text(ar.contentDetails), findsOneWidget);
    expect(find.text(ar.openFile), findsOneWidget);
    expect(find.text('نظري'), findsOneWidget); // lecture category
    // No download/share affordance anywhere on the details page (FR-055).
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
    // Every authenticated call carries the token and the device header.
    final detail = backend.sent('/catalog/contents/c1/').single;
    expect(detail.headers['Authorization'], 'Bearer access-token');
    expect(detail.headers[AuthInterceptor.deviceHeader], testInstallId);
  });

  testWidgets('second device is blocked and files a request (FR-010/011)', (
    tester,
  ) async {
    final backend = StubBackend()
      ..json(
        'POST',
        '/auth/login/',
        apiError(
          'device_not_bound',
          'This account is already linked to another device.',
          {
            'device_change_token': 'restricted-token',
            'device_change_token_expires_in': 900,
            'pending_request': null,
          },
        ),
        status: 403,
      )
      ..json('POST', '/auth/device-change-requests/', {
        'id': 'r1',
        'new_platform': 'android',
        'new_model_name': 'Test',
        'reason': 'هاتفي الجديد',
        'status': 'pending',
        'decision_note': '',
        'decided_at': null,
        'created_at': '2026-10-12T10:00:00Z',
      }, status: 201);
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.studentOtherDevice);

    expect(find.text(ar.deviceBlockedTitle), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'هاتفي الجديد');
    await tester.ensureVisible(find.text(ar.submitRequest));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.submitRequest));
    await tester.pumpAndSettle();
    expect(find.text(ar.requestSubmittedTitle), findsOneWidget);

    // Filed with the restricted token from this (new) device.
    final request = backend.sent('/auth/device-change-requests/').single;
    expect(request.headers['Authorization'], 'Bearer restricted-token');
    expect(request.headers[AuthInterceptor.deviceHeader], testInstallId);
    expect(request.data, {'reason': 'هاتفي الجديد'});

    await tester.ensureVisible(find.text(ar.backToLogin));
    await tester.tap(find.text(ar.backToLogin));
    await tester.pumpAndSettle();
    expect(find.text(ar.loginWelcome), findsOneWidget);
  });

  testWidgets('a temporary password must be changed first', (tester) async {
    final backend = studentBackend(mustChangePassword: true)
      ..json('POST', '/auth/password/change/', null, status: 204);
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.student);

    expect(find.text(ar.mustChangeTitle), findsOneWidget);
    expect(backend.sent('/catalog/universities/'), isEmpty);

    await tester.enterText(
      find.widgetWithText(TextFormField, ar.currentPassword),
      DemoAccounts.password,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.newPassword),
      'Fresh#Pass-2026',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.confirmPassword),
      'Fresh#Pass-2026',
    );
    await tester.tap(find.text(ar.changePassword));
    await tester.pumpAndSettle();

    expect(backend.sent('/auth/password/change/').single.data, {
      'current_password': DemoAccounts.password,
      'new_password': 'Fresh#Pass-2026',
    });
    expect(find.text('جامعة دمشق'), findsOneWidget);
  });

  testWidgets('logout ends the session (FR-003)', (tester) async {
    final backend = await pumpUniLect(tester, backend: studentBackend());
    await signIn(tester, DemoAccounts.student);
    await tapNav(tester, ar.navProfile);

    await tester.scrollUntilVisible(find.text(ar.logout), 200);
    await tester.tap(find.text(ar.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, ar.logout));
    await tester.pumpAndSettle();
    expect(find.text(ar.loginWelcome), findsOneWidget);
    expect(backend.sent('/auth/logout/'), hasLength(1));
  });

  testWidgets('a revoked session returns to login with a reason (FR-014)', (
    tester,
  ) async {
    final backend = studentBackend()
      ..json(
        'GET',
        '/catalog/universities/',
        apiError('session_revoked', 'Your session has ended.'),
        status: 401,
      );
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.student);
    expect(find.text(ar.loginWelcome), findsOneWidget);
    expect(find.text(ar.sessionEndedRevoked), findsOneWidget);
  });

  testWidgets('library sees its dashboard and scoped content (FR-061/062)', (
    tester,
  ) async {
    final backend = StubBackend()
      ..json(
        'POST',
        '/auth/login/',
        loginResponse(
          userJson(
            role: 'library',
            name: 'مكتبة الهندسة - دمشق',
            email: DemoAccounts.library,
            library: 1,
          ),
        ),
      )
      ..json('GET', '/manage/stats/', {
        'total': 3,
        'by_status': {
          'draft': 1,
          'pending_review': 0,
          'published': 2,
          'archived': 0,
        },
        'by_kind': {'lecture': 3, 'exam': 0},
      })
      ..json(
        'GET',
        '/manage/contents/',
        page([
          {
            ...catalogContent(id: 'c5', title: 'التوابع', lectureNumber: 5),
            'status': 'draft',
            'review_note': '',
            'library': ref(1, 'مكتبة الهندسة - دمشق'),
            'current_file': null,
            'created_by': DemoAccounts.library,
            'created_at': '2026-10-01T10:00:00Z',
            'updated_at': '2026-10-01T10:00:00Z',
            'archived_at': null,
          },
        ]),
      );
    stubShell(backend);
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.library);
    expect(find.text(ar.libraryHello), findsOneWidget);
    expect(find.text(ar.uploadLecture), findsOneWidget);
    expect(find.text('التوابع'), findsOneWidget);

    await tapNav(tester, ar.navContent);
    expect(find.text(ar.manageContent), findsOneWidget);
    expect(find.text(ar.statusDraft), findsWidgets);
  });

  testWidgets('admin approves a device change request (FR-012, FR-067)', (
    tester,
  ) async {
    var decided = false;
    final pending = {
      'id': 'dcr1',
      'student': '22222222-2222-2222-2222-222222222222',
      'student_email': 'nour@unilect.test',
      'student_name': 'نور الحسن',
      'student_number': '2023100777',
      'current_device': {
        'id': 'd1',
        'platform': 'ios',
        'model_name': 'iPhone15,3',
        'app_version': '',
        'status': 'active',
        'bound_at': '2026-09-28T10:00:00Z',
        'last_seen_at': null,
      },
      'new_platform': 'android',
      'new_model_name': 'Xiaomi 13',
      'new_app_version': '',
      'reason': 'تعطّل جهازي السابق',
      'status': 'pending',
      'decided_by': null,
      'decided_by_email': null,
      'decided_at': null,
      'decision_note': '',
      'created_at': '2026-10-11T08:00:00Z',
    };
    final backend = StubBackend()
      ..json(
        'POST',
        '/auth/login/',
        loginResponse(
          userJson(role: 'admin', name: 'مدير النظام', email: 'admin@x.test'),
        ),
      )
      ..json('GET', '/admin/dashboard/', {
        'accounts': {'student': 4, 'library': 2, 'admin': 1, 'inactive': 1},
        'content': {
          'by_status': {
            'draft': 1,
            'pending_review': 1,
            'published': 12,
            'archived': 1,
          },
          'by_kind': {'lecture': 10, 'exam': 5},
        },
        'pending_actions': {
          'device_change_requests': 1,
          'content_pending_review': 1,
          'open_reports': 1,
        },
      })
      ..on(
        'GET',
        '/admin/device-change-requests/',
        (_) => StubResponse(200, page([if (!decided) pending])),
      )
      ..on('POST', '/admin/device-change-requests/dcr1/approve/', (_) {
        decided = true;
        return StubResponse(200, {...pending, 'status': 'approved'});
      })
      ..json('GET', '/admin/audit-logs/', page(const []));
    stubShell(backend);
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.admin);
    expect(find.text(ar.adminHello), findsOneWidget);
    expect(find.text(ar.needsAction), findsOneWidget);

    await tapNav(tester, ar.navDevices);
    expect(find.text('نور الحسن'), findsOneWidget);
    expect(find.textContaining('Xiaomi 13'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, ar.approve));
    await tester.pumpAndSettle();
    expect(find.text(ar.approveDeviceConfirm), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, ar.approve).last);
    await tester.pumpAndSettle();

    expect(find.text(ar.approved), findsOneWidget);
    expect(find.text(ar.emptyRequests), findsOneWidget);
    expect(
      backend.sent('/admin/device-change-requests/').first.queryParameters,
      containsPair('status', 'pending'),
    );
  });

  testWidgets('admin creates a student account (FR-001)', (tester) async {
    final backend = StubBackend()
      ..json(
        'POST',
        '/auth/login/',
        loginResponse(userJson(role: 'admin', email: 'admin@x.test')),
      )
      ..json('GET', '/admin/dashboard/', {
        'accounts': {'student': 0, 'library': 0, 'admin': 1, 'inactive': 0},
        'content': {'by_status': <String, int>{}, 'by_kind': <String, int>{}},
        'pending_actions': {
          'device_change_requests': 0,
          'content_pending_review': 0,
          'open_reports': 0,
        },
      })
      ..json('GET', '/admin/users/', page(const []))
      ..json('GET', '/catalog/universities/', page([ref(1, 'جامعة دمشق')]))
      ..on(
        'POST',
        '/admin/users/',
        (r) => StubResponse(201, {
          ...userJson(
            role: 'student',
            name: 'طالب جديد',
            email: 'fresh@unilect.test',
            studentNumber: '2026123456',
            university: 1,
            mustChangePassword: true,
          ),
          'active_device': null,
        }),
      );
    stubShell(backend);
    await pumpUniLect(tester, backend: backend);
    await signIn(tester, DemoAccounts.admin);
    await tapNav(tester, ar.navUsers);
    await tester.tap(find.text(ar.newUser));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, ar.fullName),
      'طالب جديد',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.email),
      'fresh@unilect.test',
    );
    await tester.tap(find.widgetWithText(InputDecorator, ar.university));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جامعة دمشق').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.studentNumber),
      '2026123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.initialPassword),
      'Temp#Pass-2026',
    );
    await tester.ensureVisible(find.text(ar.save));
    await tester.tap(find.text(ar.save));
    await tester.pumpAndSettle();

    expect(find.text(ar.userCreated), findsOneWidget);
    expect(backend.sent('/admin/users/', method: 'POST').single.data, {
      'role': 'student',
      'full_name': 'طالب جديد',
      'email': 'fresh@unilect.test',
      'phone': '',
      'student_number': '2026123456',
      'university': 1,
      'library': null,
      'password': 'Temp#Pass-2026',
      'must_change_password': true,
    });
  });
}
