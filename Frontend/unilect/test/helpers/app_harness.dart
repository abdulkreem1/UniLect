import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/app/app.dart';
import 'package:unilect/core/config/app_config.dart';
import 'package:unilect/core/providers.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/l10n/gen/app_localizations.dart';

import 'harness.dart';
import 'stub_backend.dart';

final ar = lookupAppLocalizations(const Locale('ar'));

const testInstallId = 'widget-test-device-0001';

/// Pumps the real app (router, screens, providers, networking stack) with the
/// HTTP transport replaced by [backend].
Future<StubBackend> pumpUniLect(
  WidgetTester tester, {
  StubBackend? backend,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final b = backend ?? StubBackend();
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(apiBaseUrl: 'https://test.invalid/api/v1'),
        ),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        deviceIdentityProvider.overrideWithValue(FixedDevice(testInstallId)),
        httpAdapterProvider.overrideWithValue(b),
      ],
      child: const UniLectApp(),
    ),
  );
  await tester.pumpAndSettle();
  return b;
}

Future<void> signIn(
  WidgetTester tester,
  String email, {
  String password = DemoAccounts.password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, ar.email), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, ar.password),
    password,
  );
  await tester.tap(find.text(ar.signIn));
  await tester.pumpAndSettle();
}

/// Taps a bottom-navigation destination by its label.
Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
