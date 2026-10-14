import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/l10n/gen/app_localizations.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('defaults to Arabic RTL and switches to English LTR', (
    tester,
  ) async {
    await pumpUniLect(tester);
    final loginContext = tester.element(find.text(ar.loginWelcome));
    expect(Directionality.of(loginContext), TextDirection.rtl);

    await signIn(tester, DevAccounts.student);
    await tapNav(tester, ar.navProfile);
    await tester.scrollUntilVisible(find.text('English'), 200);
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
