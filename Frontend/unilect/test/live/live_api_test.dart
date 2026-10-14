/// End-to-end tests of the app's data layer against a REAL backend.
///
/// They use the app's own networking stack (interceptors, token rotation,
/// device header, error mapping) and repositories. Start a seeded server and
/// point `UNILECT_API` at it:
///
/// ```
/// python manage.py migrate && python manage.py seed_demo
/// python manage.py runserver 127.0.0.1:8001
/// UNILECT_API=http://127.0.0.1:8001/api/v1 flutter test test/live
/// ```
///
/// Each run creates its own student accounts through the admin API, so the
/// suite can be repeated against the same database.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/core/network/app_failure.dart';
import 'package:unilect/core/storage/token_storage.dart';
import 'package:unilect/features/academic/domain/academic_models.dart';
import 'package:unilect/features/admin/data/admin_repository.dart';
import 'package:unilect/features/auth/data/auth_repository.dart';
import 'package:unilect/features/auth/domain/user.dart';
import 'package:unilect/features/content/domain/content.dart';
import 'package:unilect/features/content/domain/content_draft.dart';
import 'package:unilect/features/devices/domain/device_models.dart';
import 'package:unilect/features/notifications/domain/app_notification.dart';
import 'package:unilect/features/reports/domain/content_report.dart';

import '../helpers/harness.dart';

Matcher failsWith(String code) =>
    throwsA(isA<ApiFailure>().having((f) => f.code, 'code', code));

final _random = Random();
final _run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
String unique(String prefix) =>
    '$prefix-$_run-${_random.nextInt(1 << 30).toRadixString(36)}';
String installId() => unique('live-device').padRight(16, '0');

/// Minimal valid PDF (the server checks magic bytes and parses it).
Uint8List pdf(String text) {
  final stream = 'BT /F1 18 Tf 1 0 0 1 56 760 Tm ($text) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final (i, o) in objects.indexed) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n$o\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(out.toString()));
}

UploadFile upload(String name, Uint8List bytes) => UploadFile(
  name: name,
  sizeBytes: bytes.length,
  readBytes: () async => bytes,
);

void main() {
  final base = liveApiBaseUrl;
  if (base == null) {
    test('live API tests', () {}, skip: 'Set UNILECT_API to run them');
    return;
  }

  TestDevice newDevice() => TestDevice(base, installId());

  late TestDevice admin;
  late TestDevice library;
  late Subject prog1;
  late Doctor samer;

  /// Creates a student through the admin API and signs them in on a fresh
  /// device, changing the temporary password as the app requires.
  Future<({TestDevice phone, AppUser user, String password})>
  newStudent() async {
    final universities = await admin.academic.universities();
    final damascus = universities.firstWhere((u) => u.name == 'جامعة دمشق');
    const temporary = 'Temp#Pass-2026';
    final email = '${unique('student')}@live.test';
    final created = await admin.admin.createUser(
      UserForm(
        role: UserRole.student,
        fullName: 'طالب اختبار',
        email: email,
        studentNumber: unique('n'),
        universityId: damascus.id,
        initialPassword: temporary,
      ),
    );
    expect(created.mustChangePassword, isTrue);

    final phone = newDevice();
    final outcome = await phone.login(email, password: temporary);
    final user = (outcome as LoggedIn).user;
    expect(user.mustChangePassword, isTrue);
    // Nothing but the password change is allowed yet.
    await expectLater(
      phone.academic.universities(),
      failsWith(ErrorCodes.passwordChangeRequired),
    );
    const password = 'Own#Password-2026';
    await phone.profile.changePassword(
      currentPassword: temporary,
      newPassword: password,
    );
    return (phone: phone, user: user, password: password);
  }

  setUpAll(() async {
    admin = newDevice();
    expect(await admin.login(DemoAccounts.admin), isA<LoggedIn>());
    library = newDevice();
    expect(await library.login(DemoAccounts.library), isA<LoggedIn>());

    final universities = await library.academic.universities(inScope: true);
    final faculties = await library.academic.faculties(
      universities.single.id,
      inScope: true,
    );
    final ite = faculties.firstWhere((f) => f.name.contains('المعلوماتية'));
    final years = await library.academic.years(ite.id, inScope: true);
    final subjects = await library.academic.subjects(
      years.firstWhere((y) => y.level == 1).id,
      inScope: true,
    );
    prog1 = subjects.firstWhere((s) => s.name == 'برمجة 1');
    samer = (await library.academic.doctors(prog1.id))
        .firstWhere((d) => d.fullName == 'سامر الخطيب');
  });

  group('Authentication & sessions (FR-002/003/005/014)', () {
    test('wrong password and disabled accounts are refused', () async {
      final phone = newDevice();
      await expectLater(
        phone.login(DemoAccounts.admin, password: 'wrong-password'),
        failsWith(ErrorCodes.invalidCredentials),
      );
      await expectLater(
        phone.login(DemoAccounts.disabledStudent),
        failsWith(ErrorCodes.accountDisabled),
      );
    });

    test('an expired/invalid access token is refreshed transparently; a '
        'replayed refresh token revokes the session', () async {
      final phone = newDevice();
      await phone.login(DemoAccounts.admin);
      final original = (await phone.tokens.read())!;
      await phone.tokens.save(
        StoredTokens(
          accessToken: 'not-a-valid-token',
          refreshToken: original.refreshToken,
          expiresAt: DateTime.now(),
        ),
      );
      final me = await phone.auth.fetchMe();
      expect(me.email, DemoAccounts.admin);
      final rotated = (await phone.tokens.read())!;
      expect(rotated.refreshToken, isNot(original.refreshToken));

      // Theft detection: re-using the old refresh token ends the session.
      await phone.tokens.save(
        StoredTokens(
          accessToken: 'not-a-valid-token',
          refreshToken: original.refreshToken,
          expiresAt: DateTime.now(),
        ),
      );
      await expectLater(phone.auth.fetchMe(), throwsA(isA<ApiFailure>()));
      expect(
        phone.terminations.map((t) => t.code),
        contains(ErrorCodes.sessionRevoked),
      );
      expect(await phone.tokens.read(), isNull);
    });

    test('logout revokes the session server-side', () async {
      final phone = newDevice();
      await phone.login(DemoAccounts.library);
      final tokens = (await phone.tokens.read())!;
      await phone.auth.logout();
      expect(await phone.tokens.read(), isNull);
      await phone.tokens.save(tokens);
      await expectLater(
        phone.auth.fetchMe(),
        failsWith(ErrorCodes.sessionRevoked),
      );
    });

    test('password reset always accepts and rejects a forged link', () async {
      final phone = newDevice();
      await phone.auth.requestPasswordReset('nobody@live.test');
      await expectLater(
        phone.auth.confirmPasswordReset(
          link: const ResetLink(uid: 'bm9wZQ', token: 'forged'),
          newPassword: 'Another#Pass-2026',
        ),
        failsWith(ErrorCodes.invalidResetToken),
      );
    });
  });

  group('Device binding (FR-008..015)', () {
    test('first device binds; another device is refused and requests a '
        'change that the admin approves', () async {
      final s = await newStudent();
      final email = s.user.email;
      expect(await s.phone.auth.fetchMe(), isA<AppUser>());

      // The same token from another installation is useless.
      final thief = newDevice();
      await thief.tokens.save((await s.phone.tokens.read())!);
      await expectLater(
        thief.auth.fetchMe(),
        failsWith(ErrorCodes.deviceMismatch),
      );

      final newPhone = newDevice();
      final blocked = await newPhone.login(email, password: s.password);
      expect(blocked, isA<DeviceBlocked>());
      final ticket = (blocked as DeviceBlocked).mismatch.ticket;
      final request = await newPhone.auth.submitDeviceChangeRequest(
        ticket: ticket,
        reason: 'هاتف جديد',
      );
      expect(request.status, DeviceChangeStatus.pending);
      await expectLater(
        newPhone.auth.submitDeviceChangeRequest(ticket: ticket),
        failsWith(ErrorCodes.requestAlreadyPending),
      );
      // The restricted token is refused everywhere else.
      await expectLater(
        newPhone.api.post<Object>(
          '/auth/logout/',
          authenticated: false,
          headers: {'Authorization': 'Bearer $ticket'},
        ),
        failsWith(ErrorCodes.tokenNotValid),
      );

      final pending = await admin.admin.deviceRequests(
        status: DeviceChangeStatus.pending,
      );
      final mine = pending.firstWhere((r) => r.userEmail == email);
      expect(mine.oldDevice?.platform, 'android');
      final decided = await admin.admin.decideDeviceRequest(
        mine.id,
        approve: true,
        note: 'ok',
      );
      expect(decided.status, DeviceChangeStatus.approved);

      // Old device: all sessions revoked. New device: signs in.
      await expectLater(
        s.phone.auth.fetchMe(),
        failsWith(ErrorCodes.sessionRevoked),
      );
      expect(
        await newPhone.login(email, password: s.password),
        isA<LoggedIn>(),
      );
      final notifications = await newPhone.notifications.list();
      expect(
        notifications.page.items.map((n) => n.type),
        contains(NotificationType.deviceChangeApproved),
      );

      final log = await admin.admin.deviceLogs();
      expect(
        log.items.where((e) => e.subject == email).map((e) => e.action),
        containsAll([
          DeviceLogAction.bound,
          DeviceLogAction.changeRequested,
          DeviceLogAction.approved,
        ]),
      );

      // Lost phone: the admin unbinds; the next sign-in binds again.
      await admin.admin.resetDevice(s.user.id);
      await expectLater(
        newPhone.auth.fetchMe(),
        failsWith(ErrorCodes.sessionRevoked),
      );
      expect(
        await newDevice().login(email, password: s.password),
        isA<LoggedIn>(),
      );
    });
  });

  group('Student catalog & content (FR-024..034, 050..057, 073)', () {
    test(
      'browses the active catalog down to ordered, published lectures',
      () async {
        final s = await newStudent();
        final academic = s.phone.academic;
        final universities = await academic.universities();
        expect(universities.map((u) => u.name), contains('جامعة دمشق'));
        expect(universities.map((u) => u.name), isNot(contains('جامعة البعث')));

        final subject = await academic.subject(prog1.id);
        expect(subject.code, 'ITE101');
        final terms = await academic.terms(subject.facultyId);
        expect(terms, hasLength(3));
        expect(await academic.examTypes(), hasLength(3));
        expect(await academic.lectureCategories(), hasLength(3));

        final lectures = await s.phone.content.lectures(
          prog1.id,
          doctorId: samer.id,
        );
        // Lecture 5 is still a draft.
        expect(lectures.map((c) => c.lectureNumber), [1, 2, 3, 4]);
        expect(lectures.first.classification.doctorName, 'د. سامر الخطيب');

        final exams2024 = await s.phone.content.exams(
          prog1.id,
          const ExamFilter(examYear: 2024),
        );
        expect(exams2024, hasLength(2));
        expect(exams2024.every((e) => e.examYear == 2024), isTrue);

        final search = await s.phone.content.search(
          const ContentQuery(text: 'التوابع'),
        );
        expect(search.items, isEmpty);
        final arabic = await s.phone.content.search(
          const ContentQuery(text: 'الحلقات', type: ContentType.lecture),
        );
        expect(arabic.items.single.title, 'الحلقات التكرارية');

        final detail = await s.phone.content.detail(lectures.first.id);
        expect(detail.watermarkText, startsWith('UL-'));
        expect(detail.file?.isPdf, isTrue);
        final file = await s.phone.content.file(detail.id);
        expect(latin1.decode(file.bytes.sublist(0, 5)), '%PDF-');
        expect(file.watermark, detail.watermarkText);
      },
    );

    test('favorites, follows and reports are per student', () async {
      final s = await newStudent();
      final repo = s.phone.content;
      final lecture = (await repo.lectures(prog1.id)).first;

      await repo.setFavorite(lecture.id, favorite: true);
      await repo.setFavorite(lecture.id, favorite: true); // idempotent
      expect((await repo.favorites()).map((c) => c.id), [lecture.id]);
      expect((await repo.detail(lecture.id)).isFavorite, isTrue);
      await repo.setFavorite(lecture.id, favorite: false);
      expect(await repo.favorites(), isEmpty);

      await repo.setFollowSubject(prog1.id, follow: true);
      expect(await repo.followedSubjects(), {prog1.id});
      await repo.setFollowSubject(prog1.id, follow: false);
      expect(await repo.followedSubjects(), isEmpty);

      await repo.report(lecture.id, ReportReason.wrongFile, 'خطأ في الملف');
      await expectLater(
        repo.report(lecture.id, ReportReason.other, null),
        failsWith(ErrorCodes.reportAlreadyOpen),
      );
      final reports = await admin.admin.reports(status: ReportStatus.open);
      final mine = reports.firstWhere(
        (r) => r.reporter == s.user.email && r.contentId == lecture.id,
      );
      expect(mine.reason, ReportReason.wrongFile);
      final reviewing = await admin.admin.updateReport(
        mine,
        status: ReportStatus.inReview,
        note: 'checking',
      );
      expect(reviewing.status, ReportStatus.inReview);
      final resolved = await admin.admin.updateReport(
        reviewing,
        status: ReportStatus.resolved,
      );
      expect(resolved.history.map((h) => h.status), [
        ReportStatus.inReview,
        ReportStatus.resolved,
      ]);
      final notes = await s.phone.notifications.list();
      expect(
        notes.page.items.map((n) => n.type),
        contains(NotificationType.reportUpdated),
      );
    });

    test('students cannot manage content', () async {
      final s = await newStudent();
      await expectLater(
        s.phone.manage.stats(),
        failsWith(ErrorCodes.permissionDenied),
      );
    });
  });

  group('Library publishing (FR-035..049, 060..063)', () {
    test('pickers are limited to the library scope', () async {
      final unis = await library.academic.universities(inScope: true);
      expect(unis.map((u) => u.name), ['جامعة دمشق']);
      final aleppo = newDevice();
      await aleppo.login(DemoAccounts.libraryAleppo);
      final aleppoUnis = await aleppo.academic.universities(inScope: true);
      expect(aleppoUnis.map((u) => u.name), ['جامعة حلب']);
    });

    test('upload → publish → visible; new version; archive hides it; '
        'followers are notified', () async {
      final s = await newStudent();
      await s.phone.content.setFollowSubject(prog1.id, follow: true);
      final config = await library.api.get<Map<String, dynamic>>('/config/');
      expect(config['allowed_extensions'], contains('pdf'));
      final before = await library.manage.stats();

      final categories = await library.academic.lectureCategories();
      final title = unique('محاضرة');
      final draft = ContentDraft(
        type: ContentType.lecture,
        title: title,
        subjectId: prog1.id,
        doctorId: samer.id,
        categoryId: categories.first.id,
        lectureNumber: 90,
      );
      var item = await library.manage.create(
        draft: draft,
        file: upload('lecture.pdf', pdf('Live upload')),
        publish: false,
      );
      expect(item.status, ContentStatus.draft);
      expect(item.file?.originalName, 'lecture.pdf');
      expect((await library.manage.stats()).draft, before.draft + 1);
      // Drafts are invisible to students.
      await expectLater(
        s.phone.content.detail(item.id),
        failsWith(ErrorCodes.notFound),
      );

      item = await library.manage.submit(item.id);
      expect(item.status, ContentStatus.published);
      expect((await s.phone.content.detail(item.id)).title, title);
      final notes = await s.phone.notifications.list();
      expect(
        notes.page.items.where(
          (n) => n.type == NotificationType.newContent && n.body.isNotEmpty,
        ),
        isNotEmpty,
      );
      expect(notes.unreadCount, greaterThan(0));
      await s.phone.notifications.markAllRead();
      expect(await s.phone.notifications.unreadCount(), 0);

      item = await library.manage.replaceFile(
        item.id,
        upload('lecture-v2.pdf', pdf('Version 2')),
      );
      expect(item.file?.version, 2);
      final versions = await library.manage.versions(item.id);
      expect(versions.map((v) => v.version), [2, 1]);
      expect(versions.first.isCurrent, isTrue);
      expect(versions.first.uploadedBy, DemoAccounts.library);

      final preview = await library.manage.preview(item.id);
      expect(latin1.decode(preview.bytes.sublist(0, 5)), '%PDF-');

      item = await library.manage.updateMetadata(
        item.id,
        ContentDraft.fromContent(item).copyWith(description: 'وصف محدث'),
      );
      expect(item.description, 'وصف محدث');

      item = await library.manage.archive(item.id);
      expect(item.status, ContentStatus.archived);
      await expectLater(
        s.phone.content.detail(item.id),
        failsWith(ErrorCodes.notFound),
      );
      // Library staff may only delete drafts.
      await expectLater(
        library.manage.delete(item.id),
        failsWith(ErrorCodes.invalidTransition),
      );
      item = await library.manage.restore(item.id);
      expect(item.status, ContentStatus.draft);
      await library.manage.delete(item.id);
      await expectLater(
        library.manage.get(item.id),
        failsWith(ErrorCodes.notFound),
      );
    });

    test('mandatory fields, scope and file type are enforced', () async {
      final exam = await library.manage.create(
        draft: ContentDraft(
          type: ContentType.exam,
          title: unique('امتحان'),
          subjectId: prog1.id,
        ),
        file: upload('exam.pdf', pdf('Exam')),
        publish: false,
      );
      await expectLater(
        library.manage.submit(exam.id),
        failsWith(ErrorCodes.incompleteContent),
      );
      await library.manage.delete(exam.id);

      await expectLater(
        library.manage.create(
          draft: ContentDraft(
            type: ContentType.lecture,
            title: unique('x'),
            subjectId: prog1.id,
          ),
          file: upload(
            'fake.pdf',
            Uint8List.fromList(utf8.encode('not really a pdf')),
          ),
          publish: false,
        ),
        failsWith(ErrorCodes.fileRejected),
      );

      // A course of Aleppo University is outside this library's scope.
      final aleppoUni = (await admin.academic.universities()).firstWhere(
        (u) => u.name == 'جامعة حلب',
      );
      final aleppoCourse = (await admin.academic.adminUniversitySubjects(
        aleppoUni.id,
      )).first;
      await expectLater(
        library.manage.create(
          draft: ContentDraft(
            type: ContentType.lecture,
            title: unique('x'),
            subjectId: aleppoCourse.id,
          ),
          file: upload('l.pdf', pdf('x')),
          publish: false,
        ),
        throwsA(
          isA<ApiFailure>().having((f) => f.fields.keys, 'fields', ['course']),
        ),
      );
    });

    test('with review required, submissions wait for the admin', () async {
      final settings = await admin.admin.settings();
      await admin.admin.saveSettings(
        settings.copyWith(requireContentReview: true),
      );
      try {
        final categories = await library.academic.lectureCategories();
        final item = await library.manage.create(
          draft: ContentDraft(
            type: ContentType.lecture,
            title: unique('مراجعة'),
            subjectId: prog1.id,
            doctorId: samer.id,
            categoryId: categories.first.id,
          ),
          file: upload('r.pdf', pdf('Review')),
          publish: true,
        );
        expect(item.status, ContentStatus.pendingReview);
        final queue = await admin.manage.list(
          const ManageQuery(status: ContentStatus.pendingReview),
        );
        expect(queue.items.map((c) => c.id), contains(item.id));
        final rejected = await admin.manage.reject(item.id, note: 'أعد الرفع');
        expect(rejected.status, ContentStatus.draft);
        expect(rejected.reviewNote, 'أعد الرفع');
        await library.manage.submit(item.id);
        final approved = await admin.manage.approve(item.id);
        expect(approved.status, ContentStatus.published);
        await admin.manage.delete(item.id);
      } finally {
        await admin.admin.saveSettings(settings);
      }
    });
  });

  group('Administration (FR-001, 016..023, 059, 064..069)', () {
    test('dashboard, users, audit and settings', () async {
      final dashboard = await admin.admin.dashboard();
      expect(dashboard.admins, greaterThanOrEqualTo(1));
      expect(dashboard.content.published, greaterThan(0));

      final students = await admin.admin.users(
        const UserQuery(role: UserRole.student),
      );
      expect(students.items.every((u) => u.role == UserRole.student), isTrue);
      final found = await admin.admin.users(
        const UserQuery(text: 'library.aleppo'),
      );
      expect(found.items.single.libraryName, 'مكتبة المعلوماتية - حلب');

      final audit = await admin.admin.auditLogs(category: 'auth');
      expect(audit.items, isNotEmpty);
      expect(audit.items.every((e) => e.category == 'auth'), isTrue);

      final settings = await admin.admin.settings();
      expect(settings.allowedExtensions, contains('pdf'));
    });

    test('duplicate emails are reported on the field', () async {
      await expectLater(
        admin.admin.createUser(
          const UserForm(
            role: UserRole.admin,
            fullName: 'Duplicate',
            email: DemoAccounts.admin,
            initialPassword: 'Temp#Pass-2026',
          ),
        ),
        throwsA(
          isA<ApiFailure>().having((f) => f.fields.keys, 'fields', ['email']),
        ),
      );
    });

    test('builds a catalog branch, links an instructor and reorders', () async {
      final repo = admin.academic;
      final uni = await repo.adminCreate(StructureKind.universities, {
        'name': unique('جامعة'),
        'is_active': true,
      });
      final faculty = await repo.adminCreate(StructureKind.faculties, {
        'name': 'كلية العلوم',
        'university': intId(uni.id),
      });
      final year = await repo.adminCreate(StructureKind.years, {
        'name': 'السنة الأولى',
        'number': 1,
        'faculty': intId(faculty.id),
      });
      final term = await repo.adminCreate(StructureKind.terms, {
        'name': 'الفصل الأول',
        'number': 1,
        'faculty': intId(faculty.id),
      });
      final a = await repo.adminCreate(StructureKind.subjects, {
        'name': 'مادة أ',
        'level': intId(year.id),
        'semester': intId(term.id),
      });
      final b = await repo.adminCreate(StructureKind.subjects, {
        'name': 'مادة ب',
        'level': intId(year.id),
      });
      final doctor = await repo.adminCreate(StructureKind.doctors, {
        'full_name': unique('دكتور'),
        'title': 'د.',
        'university': intId(uni.id),
      });
      await repo.setDoctorSubjects(doctor.id, {a.id, b.id});
      await repo.setDoctorSubjects(doctor.id, {b.id});
      final doctors = await repo.adminList(StructureKind.doctors);
      expect(
        doctors.cast<Doctor>().firstWhere((d) => d.id == doctor.id).subjectIds,
        [b.id],
      );

      await repo.adminReorder(StructureKind.subjects, [b.id, a.id]);
      final subjects = await repo.adminList(
        StructureKind.subjects,
        parentId: faculty.id,
      );
      expect(subjects.map((s) => s.id), [b.id, a.id]);

      // Deleting is refused while children exist; deactivating hides it.
      await expectLater(
        admin.api.delete('/admin/universities/${uni.id}/'),
        failsWith(ErrorCodes.protectedItem),
      );
      await repo.adminUpdate(StructureKind.universities, uni.id, {
        'is_active': false,
      });
      final visible = await library.academic.universities();
      expect(visible.map((u) => u.id), isNot(contains(uni.id)));
    });

    test('libraries keep their scope', () async {
      final libraries = await admin.academic.libraries();
      final damascus = libraries.firstWhere(
        (l) => l.name == 'مكتبة الهندسة - دمشق',
      );
      expect(damascus.universityIds, hasLength(1));
      expect(damascus.staffCount, greaterThanOrEqualTo(1));
    });
  });
}

int intId(String id) => int.parse(id);
