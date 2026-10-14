import 'fake_db.dart';
import 'sample_files.dart';

/// DEV ONLY — demo accounts for the fake backend. These credentials exist
/// nowhere but in this in-memory store and must never be used on a real server.
abstract final class DevAccounts {
  static const password = 'UniLect#2026';

  static const admin = 'admin@unilect.test';
  static const library = 'library@unilect.test';
  static const libraryAleppo = 'library.aleppo@unilect.test';

  /// Not yet bound to any device: the first sign-in binds the current device.
  static const student = 'student@unilect.test';

  /// Already bound to another device — demonstrates FR-010 / FR-011.
  static const studentOtherDevice = 'student2@unilect.test';

  static const disabledStudent = 'disabled@unilect.test';
}

FakeDb seededFakeDb({DateTime? now}) {
  final db = FakeDb();
  final t = now ?? DateTime.now();
  DateTime ago(int days, [int hours = 0]) =>
      t.subtract(Duration(days: days, hours: hours));

  void put(String kind, String id, Map<String, dynamic> data) =>
      db.structure[kind]![id] = {'id': id, 'isActive': true, ...data};

  // ── Structure ──
  put('universities', 'uni-dam', {'name': 'جامعة دمشق', 'sortOrder': 1});
  put('universities', 'uni-alp', {'name': 'جامعة حلب', 'sortOrder': 2});
  put('universities', 'uni-tsh', {'name': 'جامعة تشرين', 'sortOrder': 3});
  put('universities', 'uni-bth', {
    'name': 'جامعة البعث',
    'sortOrder': 4,
    'isActive': false,
  });

  put('faculties', 'fac-dam-ite', {
    'name': 'كلية الهندسة المعلوماتية',
    'universityId': 'uni-dam',
    'sortOrder': 1,
  });
  put('faculties', 'fac-dam-med', {
    'name': 'كلية الطب البشري',
    'universityId': 'uni-dam',
    'sortOrder': 2,
  });
  put('faculties', 'fac-alp-ite', {
    'name': 'كلية الهندسة المعلوماتية',
    'universityId': 'uni-alp',
    'sortOrder': 1,
  });
  put('faculties', 'fac-tsh-civ', {
    'name': 'كلية الهندسة المدنية',
    'universityId': 'uni-tsh',
    'sortOrder': 1,
  });

  const yearNames = [
    'السنة الأولى',
    'السنة الثانية',
    'السنة الثالثة',
    'السنة الرابعة',
    'السنة الخامسة',
  ];
  for (final fac in ['fac-dam-ite', 'fac-alp-ite', 'fac-dam-med']) {
    for (var i = 0; i < yearNames.length; i++) {
      put('years', '$fac-y${i + 1}', {
        'name': yearNames[i],
        'facultyId': fac,
        'level': i + 1,
        'sortOrder': i + 1,
      });
    }
  }

  put('specializations', 'spc-se', {
    'name': 'هندسة البرمجيات',
    'facultyId': 'fac-dam-ite',
    'sortOrder': 1,
  });
  put('specializations', 'spc-ai', {
    'name': 'الذكاء الصنعي',
    'facultyId': 'fac-dam-ite',
    'sortOrder': 2,
  });
  put('specializations', 'spc-net', {
    'name': 'الشبكات والنظم',
    'facultyId': 'fac-dam-ite',
    'sortOrder': 3,
  });

  void subject(
    String id,
    String name,
    String fac,
    int year,
    int order, {
    String? code,
    List<String> specs = const [],
  }) => put('subjects', id, {
    'name': name,
    'facultyId': fac,
    'yearId': '$fac-y$year',
    'code': code,
    'specializationIds': specs,
    'sortOrder': order,
  });

  subject('sub-prog1', 'برمجة 1', 'fac-dam-ite', 1, 1, code: 'ITE101');
  subject('sub-math1', 'رياضيات 1', 'fac-dam-ite', 1, 2, code: 'ITE102');
  subject('sub-phys', 'فيزياء', 'fac-dam-ite', 1, 3, code: 'ITE103');
  subject('sub-intro', 'مقدمة في الحاسوب', 'fac-dam-ite', 1, 4);
  subject('sub-db', 'قواعد البيانات', 'fac-dam-ite', 3, 1, code: 'ITE301');
  subject(
    'sub-se1',
    'هندسة البرمجيات 1',
    'fac-dam-ite',
    3,
    2,
    specs: ['spc-se'],
  );
  subject('sub-net', 'شبكات الحاسوب', 'fac-dam-ite', 3, 3, specs: ['spc-net']);
  subject('sub-alp-prog', 'برمجة 1', 'fac-alp-ite', 1, 1);
  subject('sub-anat', 'علم التشريح', 'fac-dam-med', 1, 1);

  void doctor(String id, String name, List<String> subjects, int order) => put(
    'doctors',
    id,
    {'name': name, 'subjectIds': subjects, 'sortOrder': order},
  );

  doctor('doc-samer', 'د. سامر الخطيب', ['sub-prog1', 'sub-se1'], 1);
  doctor('doc-rana', 'د. رنا العلي', ['sub-prog1', 'sub-db'], 2);
  doctor('doc-mhd', 'د. محمد الأحمد', ['sub-math1', 'sub-phys'], 3);
  doctor('doc-lina', 'د. لينا حداد', ['sub-net', 'sub-intro'], 4);
  doctor('doc-omar', 'د. عمر السيد', ['sub-alp-prog'], 5);

  put('terms', 'term-1', {'name': 'الفصل الأول', 'sortOrder': 1});
  put('terms', 'term-2', {'name': 'الفصل الثاني', 'sortOrder': 2});
  put('terms', 'term-s', {'name': 'الفصل الصيفي', 'sortOrder': 3});

  put('exam-types', 'ext-1', {'name': 'الدورة الأولى', 'sortOrder': 1});
  put('exam-types', 'ext-2', {'name': 'الدورة الثانية', 'sortOrder': 2});
  put('exam-types', 'ext-c', {'name': 'الدورة التكميلية', 'sortOrder': 3});

  // ── Users ──
  FUser user(
    String id,
    String role,
    String name,
    String email,
    int daysAgo, {
    String? number,
    Map<String, List<String>>? scope,
  }) {
    final u = FUser(
      id: id,
      publicCode: db.newPublicCode(),
      role: role,
      fullName: name,
      email: email,
      studentNumber: number,
      scope: scope,
      createdAt: ago(daysAgo),
    )..setPassword(DevAccounts.password);
    return db.users[id] = u;
  }

  final admin = user(
    'usr-admin',
    'admin',
    'مدير النظام',
    DevAccounts.admin,
    120,
  );
  final library = user(
    'usr-lib',
    'library',
    'مكتبة الهندسة - دمشق',
    DevAccounts.library,
    90,
    scope: {
      'universityIds': ['uni-dam'],
      'facultyIds': [],
    },
  );
  user(
    'usr-lib-alp',
    'library',
    'مكتبة المعلوماتية - حلب',
    DevAccounts.libraryAleppo,
    60,
    scope: {
      'universityIds': [],
      'facultyIds': ['fac-alp-ite'],
    },
  );
  final student = user(
    'usr-std',
    'student',
    'أحمد خالد',
    DevAccounts.student,
    30,
    number: '2023104512',
  );
  final student2 =
      user(
          'usr-std2',
          'student',
          'سارة يوسف',
          DevAccounts.studentOtherDevice,
          25,
          number: '2022109876',
        )
        ..boundDevice = {
          'installId': 'seed-device-0000-sara',
          'platform': 'android',
          'model': 'Samsung SM-A546',
        };
  user(
    'usr-std3',
    'student',
    'ليث منصور',
    DevAccounts.disabledStudent,
    20,
    number: '2021100001',
  ).status = 'disabled';
  final student4 =
      user(
          'usr-std4',
          'student',
          'نور الحسن',
          'nour@unilect.test',
          15,
          number: '2023100777',
        )
        ..boundDevice = {
          'installId': 'seed-device-1111-nour',
          'platform': 'ios',
          'model': 'iPhone15,3',
        };

  // A pending device-change request for the admin queue (FR-067).
  db.deviceRequests['dcr-seed'] = {
    'id': 'dcr-seed',
    'userId': student4.id,
    'userName': student4.fullName,
    'studentNumber': student4.studentNumber,
    'status': 'pending',
    'reason': 'تعطّل جهازي السابق واشتريت جهازاً جديداً',
    'oldDevice': maskDevice(student4.boundDevice),
    'newDevice': maskDevice({
      'installId': 'seed-device-2222-nour',
      'platform': 'android',
      'model': 'Xiaomi 13',
    }),
    'createdAt': ago(1, 3).toUtc().toIso8601String(),
    'decidedAt': null,
    'decidedBy': null,
    'decisionNote': null,
  };
  db.pendingDevices['dcr-seed'] = {
    'installId': 'seed-device-2222-nour',
    'platform': 'android',
    'model': 'Xiaomi 13',
  };
  for (final (u, d) in [(student2, 24), (student4, 14)]) {
    db.deviceLogs.add({
      'id': db.newId('dlog'),
      'userId': u.id,
      'userName': u.fullName,
      'action': 'bound',
      'device': maskDevice(u.boundDevice),
      'actor': null,
      'note': null,
      'createdAt': ago(d).toUtc().toIso8601String(),
    });
  }
  db.deviceLogs.insert(0, {
    'id': db.newId('dlog'),
    'userId': student4.id,
    'userName': student4.fullName,
    'action': 'changeRequested',
    'device': maskDevice(db.pendingDevices['dcr-seed']),
    'actor': null,
    'note': db.deviceRequests['dcr-seed']!['reason'],
    'createdAt': ago(1, 3).toUtc().toIso8601String(),
  });

  // ── Content ──
  FContent content(
    String id,
    String type,
    String title,
    String subjectId, {
    String? doctorId,
    int? lecture,
    int? year,
    String? term,
    String? examType,
    String status = 'published',
    int daysAgo = 10,
    String? description,
    bool image = false,
    String? ascii,
  }) {
    final c = FContent(
      id: id,
      type: type,
      title: title,
      description: description,
      subjectId: subjectId,
      doctorId: doctorId,
      lectureNumber: lecture,
      examYear: year,
      termId: term,
      examTypeId: examType,
      status: status,
      ownerId: library.id,
      createdAt: ago(daysAgo),
    );
    if (status == 'published') c.publishedAt = ago(daysAgo);
    c.versions.add(
      FFileVersion(
        version: 1,
        bytes: image
            ? SampleFiles.png()
            : SampleFiles.pdf(title: ascii ?? id, pages: 4),
        originalName: image ? '$id.png' : '$id.pdf',
        mimeType: image ? 'image/png' : 'application/pdf',
        conversionStatus: 'ready',
        uploadedAt: ago(daysAgo),
        uploadedBy: library.actor,
      ),
    );
    return db.content[id] = c;
  }

  const lectureTitles = [
    'مقدمة في البرمجة والخوارزميات',
    'المتحولات وأنماط البيانات',
    'التعليمات الشرطية',
    'الحلقات التكرارية',
    'التوابع',
  ];
  for (var i = 0; i < lectureTitles.length; i++) {
    content(
      'cnt-p1-s${i + 1}',
      'lecture',
      lectureTitles[i],
      'sub-prog1',
      doctorId: 'doc-samer',
      lecture: i + 1,
      daysAgo: 40 - i * 6,
      description: 'المحاضرة ${i + 1} من مقرر برمجة 1 للدكتور سامر الخطيب.',
      ascii: 'Programming 1 - Lecture ${i + 1}',
      status: i == 4 ? 'draft' : 'published',
    );
  }
  content(
    'cnt-p1-r1',
    'lecture',
    'مدخل إلى لغة C++',
    'sub-prog1',
    doctorId: 'doc-rana',
    lecture: 1,
    daysAgo: 35,
    ascii: 'C++ Intro',
  );
  content(
    'cnt-p1-r2',
    'lecture',
    'المؤشرات والمصفوفات',
    'sub-prog1',
    doctorId: 'doc-rana',
    lecture: 2,
    daysAgo: 28,
    ascii: 'Pointers & Arrays',
  );
  content(
    'cnt-p1-old',
    'lecture',
    'نسخة قديمة - مقدمة',
    'sub-prog1',
    doctorId: 'doc-rana',
    lecture: 1,
    daysAgo: 300,
    status: 'archived',
    ascii: 'Old',
  );
  content(
    'cnt-db-1',
    'lecture',
    'النموذج العلائقي',
    'sub-db',
    doctorId: 'doc-rana',
    lecture: 1,
    daysAgo: 12,
    ascii: 'Relational Model',
  );
  content(
    'cnt-db-2',
    'lecture',
    'لغة SQL',
    'sub-db',
    doctorId: 'doc-rana',
    lecture: 2,
    daysAgo: 5,
    status: 'pendingReview',
    ascii: 'SQL',
  );
  content(
    'cnt-m1-1',
    'lecture',
    'النهايات والاستمرار',
    'sub-math1',
    doctorId: 'doc-mhd',
    lecture: 1,
    daysAgo: 20,
    ascii: 'Limits',
  );

  content(
    'cnt-ex-p1-23',
    'exam',
    'أسئلة برمجة 1 - الدورة الأولى 2023',
    'sub-prog1',
    doctorId: 'doc-samer',
    year: 2023,
    term: 'term-1',
    examType: 'ext-1',
    daysAgo: 60,
    ascii: 'Programming 1 Exam 2023',
  );
  content(
    'cnt-ex-p1-24a',
    'exam',
    'أسئلة برمجة 1 - الدورة الأولى 2024',
    'sub-prog1',
    doctorId: 'doc-samer',
    year: 2024,
    term: 'term-1',
    examType: 'ext-1',
    daysAgo: 30,
    ascii: 'Programming 1 Exam 2024',
  );
  content(
    'cnt-ex-p1-24b',
    'exam',
    'أسئلة برمجة 1 - الدورة الثانية 2024',
    'sub-prog1',
    year: 2024,
    term: 'term-1',
    examType: 'ext-2',
    daysAgo: 25,
    image: true,
  );
  content(
    'cnt-ex-p1-25c',
    'exam',
    'أسئلة برمجة 1 - الدورة التكميلية 2025',
    'sub-prog1',
    doctorId: 'doc-rana',
    year: 2025,
    term: 'term-s',
    examType: 'ext-c',
    daysAgo: 8,
    ascii: 'Programming 1 Exam 2025',
  );
  content(
    'cnt-ex-m1-24',
    'exam',
    'أسئلة رياضيات 1 - 2024',
    'sub-math1',
    year: 2024,
    term: 'term-1',
    examType: 'ext-1',
    daysAgo: 40,
    ascii: 'Math 1 Exam 2024',
  );

  // ── Notifications, reports, audit ──
  db.notifications.add(
    FNotification(
      id: db.newId('ntf'),
      userId: student.id,
      type: 'system',
      title: 'مرحباً بك في UniLect',
      body: 'تصفّح محاضرات مقرراتك وأسئلة الدورات بأمان.',
      createdAt: ago(2),
    ),
  );
  db.reports['rep-seed'] = {
    'id': 'rep-seed',
    'contentId': 'cnt-p1-r1',
    'contentTitle': 'مدخل إلى لغة C++',
    'reason': 'duplicate',
    'note': 'المحاضرة مكررة مع محاضرة أخرى للدكتور نفسه',
    'status': 'open',
    'reporter': student2.actor,
    'createdAt': ago(3).toUtc().toIso8601String(),
    'history': <Map<String, dynamic>>[],
  };
  db.auditLogs.add({
    'id': db.newId('log'),
    'action': 'user.created',
    'actor': admin.actor,
    'entityType': 'user',
    'entityId': library.id,
    'entityLabel': library.fullName,
    'createdAt': ago(90).toUtc().toIso8601String(),
  });
  return db;
}
