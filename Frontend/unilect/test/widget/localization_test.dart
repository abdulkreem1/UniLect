import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/l10n/gen/app_localizations.dart';

import '../helpers/app_harness.dart';
import '../helpers/harness.dart';
import '../helpers/stub_backend.dart';

void main() {
  testWidgets('defaults to Arabic RTL and switches to English LTR', (
    tester,
  ) async {
    final backend = StubBackend()
      ..json(
        'POST',
        '/auth/login/',
        loginResponse(userJson(role: 'student', university: 1)),
      )
      ..json('GET', '/catalog/universities/', page([ref(1, 'جامعة دمشق')]));
    stubShell(backend);
    await pumpUniLect(tester, backend: backend);
    final loginContext = tester.element(find.text(ar.loginWelcome));
    expect(Directionality.of(loginContext), TextDirection.rtl);

    await signIn(tester, DemoAccounts.student);
    await tapNav(tester, ar.navProfile);
    // Scroll past the language row so the bottom bar does not cover it.
    await tester.scrollUntilVisible(find.text(ar.logout), 200);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.profileTitle), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(en.profileTitle).first)),
      TextDirection.ltr,
    );
    // Navigation labels switch with it.
    expect(find.text(en.navBrowse), findsOneWidget);
  });
}
