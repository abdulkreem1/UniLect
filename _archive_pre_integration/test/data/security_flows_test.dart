import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/core/network/app_failure.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/features/admin/data/admin_repository.dart';
import 'package:unilect/features/auth/data/auth_repository.dart';
import 'package:unilect/features/content/data/content_repository.dart';
import 'package:unilect/features/content/data/manage_content_repository.dart';
import 'package:unilect/features/content/domain/content.dart';
import 'package:unilect/features/content/domain/content_draft.dart';
import 'package:unilect/features/devices/domain/device_models.dart';

import '../helpers/harness.dart';

Matcher failsWith(String code) =>
    throwsA(isA<ApiFailure>().having((f) => f.code, 'code', code));

void main() {
  group('Auth (FR-002/003/005)', () {
    test('valid credentials sign in; wrong password is rejected', () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'phone-A');
      expect(await phone.login(DevAccounts.admin), isA<LoggedIn>());
      await expectLater(
        phone.auth.login(email: DevAccounts.admin, password: 'wrong-pass'),
        failsWith(ErrorCodes.invalidCredentials),
      );
    });

    test('disabled account cannot sign in', () async {
      final b = newBackend();
      await expectLater(
        TestDevice(b.backend, 'x').login(DevAccounts.disabledStudent),
        failsWith(ErrorCodes.accountDisabled),
      );
    });

    test('logout revokes the session server-side', () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'phone-A');
      await phone.login(DevAccounts.admin);
      final oldTokens = await phone.tokens.read();
      await phone.auth.logout();
      expect(await phone.tokens.read(), isNull);
      // Re-using the old token fails.
      await phone.tokens.save(oldTokens!);
      await expectLater(
        phone.auth.fetchMe(),
        failsWith(ErrorCodes.tokenRevoked),
      );
    });

    test('expired access token is refreshed transparently', () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'phone-A');
      await phone.login(DevAccounts.admin);
      final before = (await phone.tokens.read())!.accessToken;
      b.clock.advance(const Duration(minutes: 20));
      final me = await phone.auth.fetchMe();
      expect(me.email, DevAccounts.admin);
      expect((await phone.tokens.read())!.accessToken, isNot(before));
      expect(phone.terminations, isEmpty);
    });
  });

  group('Device binding (FR-008..015, FR-075)', () {
    test('full device change lifecycle', () async {
      final b = newBackend();
      final oldPhone = TestDevice(b.backend, 'old-phone');
      final newPhone = TestDevice(b.backend, 'new-phone');
      final admin = TestDevice(b.backend, 'admin-phone');

      // First sign-in binds the device.
      expect(await oldPhone.login(DevAccounts.student), isA<LoggedIn>());

      // A second device is blocked and receives a ticket.
      final outcome = await newPhone.login(DevAccounts.student);
      expect(outcome, isA<DeviceBlocked>());
      final ticket = (outcome as DeviceBlocked).mismatch.ticket;

      final request = await newPhone.auth.submitDeviceChangeRequest(
        ticket: ticket,
        reason: 'New phone',
      );
      expect(request.status, DeviceChangeStatus.pending);

      // A second pending request is refused.
      await expectLater(
        newPhone.auth.submitDeviceChangeRequest(ticket: ticket),
        failsWith(ErrorCodes.conflict),
      );

      // Admin sees and approves it.
      await admin.login(DevAccounts.admin);
      final adminRepo = AdminRepository(admin.api);
      final pending = await adminRepo.deviceRequests(
        status: DeviceChangeStatus.pending,
      );
      expect(pending.map((r) => r.id), contains(request.id));
      final decided = await adminRepo.decideDeviceRequest(
        request.id,
        approve: true,
      );
      expect(decided.status, DeviceChangeStatus.approved);
      expect(decided.decidedBy?.name, isNotEmpty);
      expect(decided.decidedAt, isNotNull);

      // Old device's session is revoked and it is told so.
      await expectLater(
        oldPhone.auth.fetchMe(),
        failsWith(ErrorCodes.tokenRevoked),
      );
      expect(oldPhone.terminations.single.code, ErrorCodes.tokenRevoked);
      expect(await oldPhone.tokens.read(), isNull);

      // Old device can no longer sign in; new device can.
      expect(await oldPhone.login(DevAccounts.student), isA<DeviceBlocked>());
      expect(await newPhone.login(DevAccounts.student), isA<LoggedIn>());

      // The log records the lifecycle.
      final logs = await adminRepo.deviceLogs();
      final actions = logs.items
          .where((l) => l.userName == decided.userName)
          .map((l) => l.action);
      expect(
        actions,
        containsAll([
          DeviceLogAction.bound,
          DeviceLogAction.changeRequested,
          DeviceLogAction.unbound,
          DeviceLogAction.approved,
        ]),
      );
    });

    test('a token replayed from another device is rejected', () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'phone-A');
      await phone.login(DevAccounts.student);
      final stolen = (await phone.tokens.read())!;

      final attacker = TestDevice(b.backend, 'phone-B');
      await attacker.tokens.save(stolen);
      await expectLater(
        attacker.auth.fetchMe(),
        failsWith(ErrorCodes.deviceNotAuthorized),
      );
    });
  });

  group(
    'Content visibility & scope (FR-039, FR-056, FR-060, FR-078, FR-079)',
    () {
      test('students only see published content', () async {
        final b = newBackend();
        final phone = TestDevice(b.backend, 'p');
        await phone.login(DevAccounts.student);
        final repo = ContentRepository(phone.api);
        final lectures = await repo.lectures('sub-prog1');
        expect(lectures, isNotEmpty);
        expect(
          lectures.every((c) => c.status == ContentStatus.published),
          isTrue,
        );
        // Drafts are unreachable even by id, and their files too.
        await expectLater(
          repo.detail('cnt-p1-s5'),
          failsWith(ErrorCodes.notFound),
        );
        await expectLater(
          repo.fileBytes('cnt-p1-old'),
          failsWith(ErrorCodes.notFound),
        );
        // Lectures are returned in the defined order.
        final samer = lectures.where((c) => c.doctorId == 'doc-samer').toList();
        expect(samer.map((c) => c.lectureNumber), orderedEquals([1, 2, 3, 4]));
      });

      test('students cannot call management endpoints', () async {
        final b = newBackend();
        final phone = TestDevice(b.backend, 'p');
        await phone.login(DevAccounts.student);
        await expectLater(
          ManageContentRepository(phone.api).stats(),
          failsWith(ErrorCodes.forbidden),
        );
        await expectLater(
          AdminRepository(phone.api).dashboard(),
          failsWith(ErrorCodes.forbidden),
        );
      });

      test('library cannot manage content outside its scope', () async {
        final b = newBackend();
        final aleppo = TestDevice(b.backend, 'lib');
        await aleppo.login(DevAccounts.libraryAleppo);
        final repo = ManageContentRepository(aleppo.api);
        final page = await repo.list(const ManageQuery());
        expect(page.items, isEmpty); // Damascus content is invisible.
        await expectLater(
          repo.setStatus('cnt-p1-s1', ContentStatus.archived),
          failsWith(ErrorCodes.outOfScope),
        );
      });

      test(
        'publishing requires mandatory fields; file type is validated',
        () async {
          final b = newBackend();
          final lib = TestDevice(b.backend, 'lib');
          await lib.login(DevAccounts.library);
          final repo = ManageContentRepository(lib.api);
          final pdf = UploadFile(
            name: 'lecture.pdf',
            sizeBytes: 8,
            readBytes: () async => Uint8List.fromList('%PDF-1.4'.codeUnits),
          );
          const missingDoctor = ContentDraft(
            type: ContentType.lecture,
            title: 'Recursion',
            subjectId: 'sub-prog1',
          );
          await expectLater(
            repo.create(draft: missingDoctor, file: pdf, publish: true),
            failsWith(ErrorCodes.validationFailed),
          );
          // Same metadata is fine as a draft.
          final draft = await repo.create(
            draft: missingDoctor,
            file: pdf,
            publish: false,
          );
          expect(draft.status, ContentStatus.draft);

          final fakeExe = UploadFile(
            name: 'virus.exe',
            sizeBytes: 2,
            readBytes: () async => Uint8List.fromList([0x4D, 0x5A]),
          );
          await expectLater(
            repo.create(draft: missingDoctor, file: fakeExe, publish: false),
            failsWith(ErrorCodes.fileTypeNotAllowed),
          );
          final spoofed = UploadFile(
            name: 'fake.pdf',
            sizeBytes: 2,
            readBytes: () async => Uint8List.fromList([0x4D, 0x5A]),
          );
          await expectLater(
            repo.create(draft: missingDoctor, file: spoofed, publish: false),
            failsWith(ErrorCodes.fileTypeNotAllowed),
          );
        },
      );

      test('profile rejects protected fields (FR-007)', () async {
        final b = newBackend();
        final phone = TestDevice(b.backend, 'p');
        await phone.login(DevAccounts.student);
        await expectLater(
          phone.api.patch<Map<String, dynamic>>(
            '/me',
            body: {'fullName': 'Hacker', 'studentNumber': '1'},
          ),
          failsWith(ErrorCodes.protectedField),
        );
      });
    },
  );
}
