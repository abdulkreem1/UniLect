import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';

import '../helpers/app_harness.dart';

void main() {
  group('Login (FR-002)', () {
    testWidgets('validates fields before calling the server', (tester) async {
      await pumpUniLect(tester);
      expect(find.text(ar.loginWelcome), findsOneWidget);
      expect(find.text(ar.devRibbon), findsOneWidget);

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
    });

    testWidgets('wrong credentials show a clear message', (tester) async {
      await pumpUniLect(tester);
      await signIn(tester, DevAccounts.student, password: 'wrong-password');
      expect(find.text(ar.invalidCredentials), findsOneWidget);
      expect(find.text(ar.loginWelcome), findsOneWidget);
    });

    testWidgets('disabled account is refused', (tester) async {
      await pumpUniLect(tester);
      await signIn(tester, DevAccounts.disabledStudent);
      expect(find.textContaining('معطّل'), findsOneWidget);
    });
  });

  testWidgets('student browses university → faculty → year → subject', (
    tester,
  ) async {
    await pumpUniLect(tester);
    await signIn(tester, DevAccounts.student);

    expect(find.text(ar.greeting('أحمد')), findsOneWidget);
    expect(find.text('جامعة دمشق'), findsOneWidget);
    expect(find.text('جامعة البعث'), findsNothing); // inactive (FR-024)

    await tester.tap(find.text('جامعة دمشق'));
    await tester.pumpAndSettle();
    expect(find.text('كلية الهندسة المعلوماتية'), findsOneWidget);

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
    // Published lectures only, in order; the draft (#5) is not listed.
    expect(find.text('مقدمة في البرمجة والخوارزميات'), findsOneWidget);
    expect(find.text('التوابع'), findsNothing);
    expect(find.text(ar.lecturesCount(4)), findsOneWidget);

    await tester.tap(find.text('مقدمة في البرمجة والخوارزميات'));
    await tester.pumpAndSettle();
    expect(find.text(ar.contentDetails), findsOneWidget);
    expect(find.text(ar.openFile), findsOneWidget);
    expect(find.text(ar.classification), findsOneWidget);
    // No download/share affordance anywhere on the details page (FR-055).
    expect(find.byIcon(Icons.download_rounded), findsNothing);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
  });

  testWidgets(
    'second device is blocked and can file a request (FR-010, FR-011)',
    (tester) async {
      await pumpUniLect(tester);
      await signIn(tester, DevAccounts.studentOtherDevice);

      expect(find.text(ar.deviceBlockedTitle), findsOneWidget);
      expect(find.text(ar.deviceHowTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'هاتفي الجديد');
      await tester.ensureVisible(find.text(ar.submitRequest));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ar.submitRequest));
      await tester.pumpAndSettle();
      expect(find.text(ar.requestSubmittedTitle), findsOneWidget);

      await tester.ensureVisible(find.text(ar.backToLogin));
      await tester.tap(find.text(ar.backToLogin));
      await tester.pumpAndSettle();
      expect(find.text(ar.loginWelcome), findsOneWidget);
    },
  );

  testWidgets('logout ends the session (FR-003)', (tester) async {
    await pumpUniLect(tester);
    await signIn(tester, DevAccounts.student);
    await tapNav(tester, ar.navProfile);

    await tester.scrollUntilVisible(find.text(ar.logout), 200);
    await tester.tap(find.text(ar.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, ar.logout));
    await tester.pumpAndSettle();
    expect(find.text(ar.loginWelcome), findsOneWidget);
  });

  testWidgets(
    'library sees its dashboard and scoped content (FR-061, FR-062)',
    (tester) async {
      await pumpUniLect(tester);
      await signIn(tester, DevAccounts.library);
      expect(find.text(ar.libraryHello), findsOneWidget);
      expect(find.text(ar.uploadLecture), findsOneWidget);

      await tapNav(tester, ar.navContent);
      expect(find.text(ar.manageContent), findsOneWidget);
      expect(find.text(ar.statusDraft), findsWidgets);
    },
  );

  testWidgets('admin approves a device change request (FR-012, FR-067)', (
    tester,
  ) async {
    await pumpUniLect(tester);
    await signIn(tester, DevAccounts.admin);
    expect(find.text(ar.adminHello), findsOneWidget);
    expect(find.text(ar.needsAction), findsOneWidget);

    await tapNav(tester, ar.navDevices);
    expect(find.text('نور الحسن'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, ar.approve));
    await tester.pumpAndSettle();
    expect(find.text(ar.approveDeviceConfirm), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, ar.approve).last);
    await tester.pumpAndSettle();

    expect(find.text(ar.approved), findsOneWidget);
    expect(find.text(ar.emptyRequests), findsOneWidget);
  });

  testWidgets('admin creates a student account (FR-001)', (tester) async {
    final backend = await pumpUniLect(tester);
    await signIn(tester, DevAccounts.admin);
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
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.studentNumber),
      '2026123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, ar.initialPassword),
      'Temp#Pass1',
    );
    await tester.ensureVisible(find.text(ar.save));
    await tester.tap(find.text(ar.save));
    await tester.pumpAndSettle();

    expect(find.text(ar.userCreated), findsOneWidget);
    final created = backend.db.users.values.where(
      (u) => u.email == 'fresh@unilect.test',
    );
    expect(created.single.role, 'student');
    expect(created.single.studentNumber, '2026123456');
  });
}
