import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/app/app.dart';
import 'package:unilect/core/config/app_config.dart';
import 'package:unilect/core/providers.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/dev/fake_backend/fake_backend.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/l10n/gen/app_localizations.dart';

import 'harness.dart';

final ar = lookupAppLocalizations(const Locale('ar'));

/// Pumps the real app (router, screens, providers) wired to an in-memory
/// backend with zero latency.
Future<FakeBackend> pumpUniLect(
  WidgetTester tester, {
  FakeBackend? backend,
  String installId = 'widget-test-device',
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final b = backend ?? FakeBackend(db: seededFakeDb());
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://test.invalid/api/v1',
            useFakeBackend: true,
          ),
        ),
        secureStoreProvider.overrideWithValue(MemorySecureStore()),
        deviceIdentityProvider.overrideWithValue(FixedDevice(installId)),
        fakeBackendProvider.overrideWithValue(b),
        fakeLatencyProvider.overrideWithValue(Duration.zero),
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
  String? password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, ar.email), email);
  await tester.enterText(
    find.widgetWithText(TextFormField, ar.password),
    password ?? DevAccounts.password,
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
