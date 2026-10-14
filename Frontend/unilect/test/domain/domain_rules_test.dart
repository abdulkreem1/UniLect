import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/models/json.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/features/content/domain/content.dart';
import 'package:unilect/features/content/domain/content_draft.dart';
import 'package:unilect/features/library/domain/upload_validation.dart';
import 'package:unilect/features/reports/domain/content_report.dart';
import 'package:unilect/features/settings/domain/client_config.dart';

import '../helpers/stub_backend.dart';

UploadFile file(String name, int size) => UploadFile(
  name: name,
  sizeBytes: size,
  readBytes: () async => Uint8List(0),
);

void main() {
  group('ContentDraft mandatory fields (FR-036, FR-046, FR-078)', () {
    test(
      'a lecture needs title + subject to save, doctor and category to publish',
      () {
        const empty = ContentDraft(type: ContentType.lecture);
        expect(empty.missingForSave(), {DraftField.title, DraftField.subject});

        const incomplete = ContentDraft(
          type: ContentType.lecture,
          title: 'Intro',
          subjectId: '12',
        );
        expect(incomplete.missingForSave(), isEmpty);
        expect(incomplete.missingForPublish(), {
          DraftField.doctor,
          DraftField.category,
        });

        final complete = incomplete.copyWith(
          doctorId: const Nullable('5'),
          categoryId: const Nullable('7'),
        );
        expect(complete.missingForPublish(), isEmpty);
      },
    );

    test('an exam needs year, semester and session type to publish; doctor '
        'optional', () {
      const exam = ContentDraft(
        type: ContentType.exam,
        title: 'Final 2024',
        subjectId: '12',
      );
      expect(exam.missingForPublish(), {
        DraftField.examYear,
        DraftField.term,
        DraftField.examType,
      });
      final complete = exam.copyWith(
        examYear: const Nullable(2024),
        termId: const Nullable('3'),
        examTypeId: const Nullable('4'),
      );
      expect(complete.missingForPublish(), isEmpty);
    });

    test('toFields uses API names and integer ids; other-kind fields null', () {
      const lecture = ContentDraft(
        type: ContentType.lecture,
        title: '  Intro  ',
        subjectId: '12',
        doctorId: '5',
        categoryId: '7',
        lectureNumber: 3,
        examYear: 2020,
        termId: '9',
      );
      expect(lecture.toFields(), {
        'kind': 'lecture',
        'title': 'Intro',
        'description': '',
        'course': 12,
        'instructor': 5,
        'lecture_number': 3,
        'category': 7,
        'exam_year': null,
        'exam_type': null,
        'semester': null,
      });
    });

    test('copyWith distinguishes "unchanged" from "cleared"', () {
      const d = ContentDraft(type: ContentType.lecture, doctorId: '1');
      expect(d.copyWith(title: 'x').doctorId, '1');
      expect(d.copyWith(doctorId: const Nullable(null)).doctorId, isNull);
    });
  });

  group('Content parsing', () {
    test('reads the student catalog representation', () {
      final c = Content.fromJson(
        catalogContent(id: 'c1', title: 'Intro', lectureNumber: 1),
      );
      expect(c.status, ContentStatus.published);
      expect(c.subjectId, '1000');
      expect(c.doctorId, '50');
      expect(c.categoryId, '7');
      expect(c.classification.doctorName, 'د. سامر الخطيب');
      expect(c.classification.yearName, 'السنة الأولى');
      expect(c.file?.isPdf, isTrue);
      expect(c.watermarkText, 'UL-ABCDEF1234');
      expect(c.description, isNull);
    });

    test('reads the manage representation (status, no file yet)', () {
      final c = Content.fromJson({
        ...catalogContent(id: 'c2', title: 'Draft', kind: 'exam'),
        'status': 'pending_review',
        'review_note': 'Fix the year',
        'current_file': null,
        'file': null,
        'library': ref(1, 'Lib'),
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-02T10:00:00Z',
      });
      expect(c.status, ContentStatus.pendingReview);
      expect(c.type, ContentType.exam);
      expect(c.termId, '9');
      expect(c.examTypeId, '8');
      expect(c.file, isNull);
      expect(c.reviewNote, 'Fix the year');
      expect(c.libraryName, 'Lib');
    });

    test('stats come from by_status', () {
      final s = ContentStats.fromJson({
        'total': 6,
        'by_status': {
          'draft': 1,
          'pending_review': 2,
          'published': 3,
          'archived': 0,
        },
      });
      expect([s.draft, s.pendingReview, s.published, s.archived], [1, 2, 3, 0]);
    });
  });

  group('Upload pre-check (FR-043)', () {
    const config = ClientConfig(
      maxUploadSizeMb: 2,
      allowedExtensions: ['pdf', 'png'],
      requireContentReview: false,
    );

    test('accepts allowed types within the size limit (case-insensitive)', () {
      expect(checkUpload(file('Lecture.PDF', 1024), config), isNull);
    });

    test('rejects disallowed or missing extensions', () {
      expect(
        checkUpload(file('setup.exe', 10), config),
        isA<FileTypeNotAllowed>().having((p) => p.extension, 'ext', 'exe'),
      );
      expect(checkUpload(file('noext', 10), config), isA<FileTypeNotAllowed>());
    });

    test('rejects files above the configured size', () {
      expect(
        checkUpload(file('big.pdf', 3 * 1024 * 1024), config),
        isA<FileTooLarge>().having((p) => p.maxMb, 'max', 2),
      );
    });
  });

  group('Queries', () {
    test('ContentQuery maps to catalog filters and counts active ones', () {
      const q = ContentQuery(
        text: ' ',
        type: ContentType.exam,
        yearId: '4',
        doctorId: '5',
      );
      expect(q.activeFilterCount, 3);
      expect(q.isEmpty, isFalse);
      expect(const ContentQuery().isEmpty, isTrue);
      expect(q.toQuery(), containsPair('search', ''));
      expect(q.toQuery(), containsPair('kind', 'exam'));
      expect(q.toQuery(), containsPair('level', '4'));
      expect(q.toQuery(), containsPair('instructor', '5'));
    });

    test('ExamFilter value equality makes it a safe provider key', () {
      expect(
        const ExamFilter(examYear: 2024),
        equals(const ExamFilter(examYear: 2024)),
      );
      final f = const ExamFilter().copyWith(termId: const Nullable('t'));
      expect(f.activeCount, 1);
      expect(f.toQuery(), containsPair('semester', 't'));
    });
  });

  test('Report statuses follow the server transitions (FR-074)', () {
    expect(ReportStatus.fromApi('in_review'), ReportStatus.inReview);
    expect(ReportStatus.fromApi('rejected'), ReportStatus.dismissed);
    expect(ReportStatus.open.next, contains(ReportStatus.resolved));
    expect(ReportStatus.resolved.next, isEmpty);
    expect(ReportReason.wrongFile.apiValue, 'wrong');
  });
}
