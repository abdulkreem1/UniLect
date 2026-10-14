import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/core/network/app_failure.dart';
import 'package:unilect/dev/fake_backend/fake_seed.dart';
import 'package:unilect/features/academic/data/academic_repository.dart';
import 'package:unilect/features/academic/domain/academic_models.dart';
import 'package:unilect/features/admin/data/admin_repository.dart';
import 'package:unilect/features/auth/data/auth_repository.dart';
import 'package:unilect/features/auth/domain/user.dart';
import 'package:unilect/features/content/data/content_repository.dart';
import 'package:unilect/features/content/data/manage_content_repository.dart';
import 'package:unilect/features/content/domain/content.dart';
import 'package:unilect/features/content/domain/content_draft.dart';
import 'package:unilect/features/devices/domain/device_models.dart';
import 'package:unilect/features/notifications/data/notifications_repository.dart';
import 'package:unilect/features/notifications/domain/app_notification.dart';

import '../helpers/harness.dart';

Matcher failsWith(String code) =>
    throwsA(isA<ApiFailure>().having((f) => f.code, 'code', code));

UploadFile pdf([String name = 'file.pdf']) => UploadFile(
  name: name,
  sizeBytes: 9,
  readBytes: () async => Uint8List.fromList('%PDF-1.4\n'.codeUnits),
);

const lectureDraft = ContentDraft(
  type: ContentType.lecture,
  title: 'Recursion',
  subjectId: 'sub-prog1',
  doctorId: 'doc-samer',
  lectureNumber: 6,
);

void main() {
  test(
    'content review workflow (FR-066) and follower notification (FR-071)',
    () async {
      final b = newBackend();
      final admin = TestDevice(b.backend, 'a');
      final lib = TestDevice(b.backend, 'l');
      final student = TestDevice(b.backend, 's');
      await admin.login(DevAccounts.admin);
      await lib.login(DevAccounts.library);
      await student.login(DevAccounts.student);

      final adminRepo = AdminRepository(admin.api);
      final settings = await adminRepo.settings();
      await adminRepo.saveSettings(
        settings.copyWith(requireContentReview: true),
      );

      await ContentRepository(student.api)
          .setFollowSubject('sub-prog1', follow: true);

      final created = await ManageContentRepository(lib.api)
          .create(draft: lectureDraft, file: pdf(), publish: true);
      expect(created.status, ContentStatus.pendingReview);

      final studentRepo = ContentRepository(student.api);
      await expectLater(
        studentRepo.detail(created.id),
        failsWith(ErrorCodes.notFound),
      );

      final reviewed = await ManageContentRepository(admin.api)
          .review(created.id, approve: true);
      expect(reviewed.status, ContentStatus.published);
      expect((await studentRepo.detail(created.id)).title, 'Recursion');

      final studentNotes = await NotificationsRepository(student.api).list();
      expect(
        studentNotes.page.items.map((n) => n.type),
        contains(NotificationType.newContent),
      );
      final libNotes = await NotificationsRepository(lib.api).list();
      expect(
        libNotes.page.items.map((n) => n.type),
        contains(NotificationType.contentReviewed),
      );
    },
  );

  test('rejected device request notifies the student (FR-070)', () async {
    final b = newBackend();
    final old = TestDevice(b.backend, 'old');
    final fresh = TestDevice(b.backend, 'new');
    final admin = TestDevice(b.backend, 'a');
    await old.login(DevAccounts.student);
    final blocked = await fresh.login(DevAccounts.student) as DeviceBlocked;
    final request = await fresh.auth.submitDeviceChangeRequest(
      ticket: blocked.mismatch.ticket,
    );
    await admin.login(DevAccounts.admin);
    final decided = await AdminRepository(
      admin.api,
    ).decideDeviceRequest(request.id, approve: false, note: 'Visit the office');
    expect(decided.status, DeviceChangeStatus.rejected);
    expect(decided.decisionNote, 'Visit the office');

    // Old device keeps working and receives the notification.
    final notes = await NotificationsRepository(old.api).list();
    expect(notes.unreadCount, greaterThan(0));
    expect(notes.page.items.first.type, NotificationType.deviceChangeRejected);
    // New device is still blocked.
    expect(await fresh.login(DevAccounts.student), isA<DeviceBlocked>());
  });

  test(
    'favorites are stored on the account and survive re-login (FR-034)',
    () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'p');
      await phone.login(DevAccounts.student);
      await ContentRepository(phone.api)
          .setFavorite('cnt-p1-s1', favorite: true);
      await phone.auth.logout();
      await phone.login(DevAccounts.student);
      final favs = await ContentRepository(phone.api).favorites();
      expect(favs.single.id, 'cnt-p1-s1');
      expect(favs.single.isFavorite, isTrue);
    },
  );

  test(
    'search respects keywords and filters (FR-031, FR-032, FR-050)',
    () async {
      final b = newBackend();
      final phone = TestDevice(b.backend, 'p');
      await phone.login(DevAccounts.student);
      final repo = ContentRepository(phone.api);

      final exams = await repo.search(
        const ContentQuery(type: ContentType.exam),
      );
      expect(exams.items, isNotEmpty);
      expect(exams.items.every((c) => c.type == ContentType.exam), isTrue);

      final byDoctor = await repo.search(
        const ContentQuery(doctorId: 'doc-rana'),
      );
      expect(byDoctor.items.every((c) => c.doctorId == 'doc-rana'), isTrue);

      final keyword = await repo.search(const ContentQuery(text: 'SQL'));
      expect(keyword.items, isEmpty); // Only pending review → invisible.

      final filtered = await repo.exams(
        'sub-prog1',
        const ExamFilter(examYear: 2024, examTypeId: 'ext-2'),
      );
      expect(filtered.single.id, 'cnt-ex-p1-24b');
    },
  );

  test('library lookups are limited to the scope (FR-060)', () async {
    final b = newBackend();
    final lib = TestDevice(b.backend, 'l');
    await lib.login(DevAccounts.libraryAleppo);
    final unis = await AcademicRepository(lib.api).universities();
    expect(unis.map((u) => u.id), ['uni-alp']);
    expect(await AcademicRepository(lib.api).years('fac-dam-ite'), isEmpty);
  });

  test('inactive structure is hidden from students (FR-016, FR-024)', () async {
    final b = newBackend();
    final admin = TestDevice(b.backend, 'a');
    final student = TestDevice(b.backend, 's');
    await admin.login(DevAccounts.admin);
    await student.login(DevAccounts.student);
    final academic = AcademicRepository(student.api);
    expect(
      (await academic.universities()).map((u) => u.id),
      isNot(contains('uni-bth')),
    );

    await AcademicRepository(
      admin.api,
    ).adminUpdate(StructureKind.universities, 'uni-dam', {'isActive': false});
    expect(
      (await academic.universities()).map((u) => u.id),
      isNot(contains('uni-dam')),
    );
    // Content under it disappears as well.
    await expectLater(
      ContentRepository(student.api).detail('cnt-p1-s1'),
      failsWith(ErrorCodes.notFound),
    );
  });

  test(
    'a faculty requires a valid university (FR-017); reorder persists (FR-023)',
    () async {
      final b = newBackend();
      final admin = TestDevice(b.backend, 'a');
      await admin.login(DevAccounts.admin);
      final repo = AcademicRepository(admin.api);
      await expectLater(
        repo.adminCreate(StructureKind.faculties, {
          'name': 'Law',
          'universityId': 'nope',
        }),
        failsWith(ErrorCodes.validationFailed),
      );
      await repo.adminReorder(StructureKind.universities, [
        'uni-tsh',
        'uni-alp',
        'uni-dam',
        'uni-bth',
      ]);
      final student = TestDevice(b.backend, 's');
      await student.login(DevAccounts.student);
      final order = await AcademicRepository(student.api).universities();
      expect(order.map((u) => u.id), ['uni-tsh', 'uni-alp', 'uni-dam']);
    },
  );

  test('account management: unique email, disable revokes sessions (FR-001, FR-005)', () async {
    final b = newBackend();
    final admin = TestDevice(b.backend, 'a');
    await admin.login(DevAccounts.admin);
    final repo = AdminRepository(admin.api);

    final created = await repo.createUser(
      const UserForm(
        role: UserRole.student,
        fullName: 'New Student',
        email: 'new@unilect.test',
        studentNumber: '2026000001',
        initialPassword: 'Temp#Pass1',
      ),
    );
    expect(created.id, isNotEmpty);
    expect(created.publicCode, startsWith('UL-'));

    await expectLater(
      repo.createUser(
        const UserForm(
          role: UserRole.student,
          fullName: 'Dup',
          email: 'NEW@unilect.test',
          studentNumber: '1',
          initialPassword: 'Temp#Pass1',
        ),
      ),
      failsWith(ErrorCodes.conflict),
    );

    final phone = TestDevice(b.backend, 'p');
    await phone.auth.login(email: 'new@unilect.test', password: 'Temp#Pass1');
    await repo.setUserEnabled(created.id, enabled: false);
    await expectLater(phone.auth.fetchMe(), failsWith(ErrorCodes.tokenRevoked));
    await expectLater(
      phone.auth.login(email: 'new@unilect.test', password: 'Temp#Pass1'),
      failsWith(ErrorCodes.accountDisabled),
    );
  });

  test('password reset verifies identity first (FR-004)', () async {
    final b = newBackend();
    final phone = TestDevice(b.backend, 'p');
    await phone.auth.requestPasswordReset(DevAccounts.admin);
    final code = b.backend.lastIssuedResetCode!;
    await expectLater(
      phone.auth.verifyResetCode(email: DevAccounts.admin, code: '000000'),
      failsWith(ErrorCodes.invalidResetCode),
    );
    final token = await phone.auth.verifyResetCode(
      email: DevAccounts.admin,
      code: code,
    );
    await phone.auth.resetPassword(
      resetToken: token,
      newPassword: 'Brand#New9',
    );
    // Token is single-use.
    await expectLater(
      phone.auth.resetPassword(resetToken: token, newPassword: 'Other#Pass9'),
      failsWith(ErrorCodes.invalidResetCode),
    );
    await expectLater(
      phone.login(DevAccounts.admin),
      failsWith(ErrorCodes.invalidCredentials),
    );
    expect(
      await phone.auth.login(email: DevAccounts.admin, password: 'Brand#New9'),
      isA<LoggedIn>(),
    );
  });

  test('unknown emails get the same answer (no enumeration)', () async {
    final b = newBackend();
    final phone = TestDevice(b.backend, 'p');
    await phone.auth.requestPasswordReset('nobody@unilect.test');
    expect(b.backend.lastIssuedResetCode, isNull);
  });

  test(
    'replacing a file keeps metadata and serves the new version (FR-041)',
    () async {
      final b = newBackend();
      final lib = TestDevice(b.backend, 'l');
      final student = TestDevice(b.backend, 's');
      await lib.login(DevAccounts.library);
      await student.login(DevAccounts.student);
      final repo = ManageContentRepository(lib.api);
      final updated = await repo.replaceFile('cnt-p1-s1', pdf('v2.pdf'));
      expect(updated.file.version, 2);
      expect(updated.title, 'مقدمة في البرمجة والخوارزميات');
      final versions = await repo.versions('cnt-p1-s1');
      expect(versions.first.isCurrent, isTrue);
      expect(versions.length, 2);
      final bytes = await ContentRepository(student.api).fileBytes('cnt-p1-s1');
      expect(bytes.length, 9);
    },
  );

  test('archived content disappears for students (FR-040, FR-042)', () async {
    final b = newBackend();
    final lib = TestDevice(b.backend, 'l');
    final student = TestDevice(b.backend, 's');
    await lib.login(DevAccounts.library);
    await student.login(DevAccounts.student);
    await ManageContentRepository(lib.api)
        .setStatus('cnt-p1-s2', ContentStatus.archived);
    await expectLater(
      ContentRepository(student.api).detail('cnt-p1-s2'),
      failsWith(ErrorCodes.notFound),
    );
    final stats = await ManageContentRepository(lib.api).stats();
    expect(stats.archived, greaterThanOrEqualTo(2));
  });

  test('library cannot hide content (admin-only status)', () async {
    final b = newBackend();
    final lib = TestDevice(b.backend, 'l');
    await lib.login(DevAccounts.library);
    await expectLater(
      ManageContentRepository(lib.api)
          .setStatus('cnt-p1-s1', ContentStatus.hidden),
      failsWith(ErrorCodes.validationFailed),
    );
  });

  test('audit log records administrative actions (FR-068)', () async {
    final b = newBackend();
    final admin = TestDevice(b.backend, 'a');
    await admin.login(DevAccounts.admin);
    final repo = AdminRepository(admin.api);
    await repo.saveSettings(
      (await repo.settings()).copyWith(maxUploadSizeMb: 10),
    );
    final logs = await repo.auditLogs(entityType: 'settings');
    expect(logs.items.first.action, 'settings.updated');
    expect(logs.items.first.actor.name, isNotEmpty);
  });
}
