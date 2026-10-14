import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unilect/app/app.dart';
import 'package:unilect/core/providers.dart';
import 'package:unilect/core/storage/secure_store.dart';
import 'package:unilect/features/viewer/presentation/secure_viewer_screen.dart';

import '../test/helpers/app_harness.dart' show ar, signIn;
import '../test/helpers/harness.dart';

/// End-to-end on a device/emulator against a running, seeded backend
/// (`manage.py seed_demo`):
///
///   flutter test integration_test -d DEVICE_ID
///     --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
///
/// The fixed install ID makes the demo student's first sign-in bind this
/// "device", so the test can be repeated.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          secureStoreProvider.overrideWithValue(MemorySecureStore()),
          deviceIdentityProvider.overrideWithValue(
            FixedDevice('integration-test-device-0001'),
          ),
        ],
        child: const UniLectApp(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );

  testWidgets('student opens a lecture in the secure viewer', (tester) async {
    await pumpApp(tester);
    await signIn(tester, DemoAccounts.student);
    await settle(tester);

    for (final label in [
      'جامعة دمشق',
      'كلية الهندسة المعلوماتية',
      'السنة الأولى',
      'برمجة 1',
      'د. سامر الخطيب',
      'مقدمة في البرمجة والخوارزميات',
    ]) {
      await tester.tap(find.text(label));
      await settle(tester);
    }

    await tester.tap(find.text(ar.openFile));
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(find.byType(SecureViewerScreen), findsOneWidget);
    expect(find.text(ar.viewerProtected), findsOneWidget);
    // Page indicator appears once pdfium has opened the seeded 4-page PDF.
    expect(find.text(ar.pageOf(1, 4)), findsOneWidget);
  });

  testWidgets('library uploads are validated before publishing', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, DemoAccounts.library);
    await settle(tester);
    await tester.tap(find.text(ar.uploadLecture));
    await settle(tester);
    await tester.tap(find.text(ar.preview));
    await settle(tester);
    // No file and no metadata: the form refuses to continue (FR-078).
    expect(find.text(ar.fileRequired), findsOneWidget);
  });
}
