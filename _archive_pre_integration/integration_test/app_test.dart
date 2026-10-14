import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/features/viewer/presentation/secure_viewer_screen.dart';

import '../test/helpers/app_harness.dart';

/// End-to-end on a device/emulator against the dev fake backend:
///   `flutter test integration_test -d DEVICE_ID`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('student opens a lecture in the secure viewer', (tester) async {
    await pumpUniLect(tester);
    await signIn(tester, DevAccounts.student);

    await tester.tap(find.text('جامعة دمشق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كلية الهندسة المعلوماتية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السنة الأولى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('برمجة 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('د. سامر الخطيب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مقدمة في البرمجة والخوارزميات'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ar.openFile));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 15),
    );

    expect(find.byType(SecureViewerScreen), findsOneWidget);
    expect(find.text(ar.viewerProtected), findsOneWidget);
    // Page indicator appears once pdfium has opened the document.
    expect(find.text(ar.pageOf(1, 4)), findsOneWidget);
  });

  testWidgets('library uploads are validated before publishing', (
    tester,
  ) async {
    await pumpUniLect(tester);
    await signIn(tester, DevAccounts.library);
    await tester.tap(find.text(ar.uploadLecture));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ar.preview));
    await tester.pumpAndSettle();
    // No file and no metadata: the form refuses to continue (FR-078).
    expect(find.text(ar.fileRequired), findsOneWidget);
  });
}
