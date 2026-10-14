import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:unilect/core/models/json.dart';
import 'package:unilect/core/network/api_client.dart';
import 'package:unilect/features/content/domain/content.dart';
import 'package:unilect/features/content/domain/content_draft.dart';
import 'package:unilect/features/library/domain/upload_validation.dart';
import 'package:unilect/features/settings/domain/client_config.dart';

UploadFile file(String name, int size) => UploadFile(
  name: name,
  sizeBytes: size,
  readBytes: () async => Uint8List(0),
);

void main() {
  group('ContentDraft mandatory fields (FR-036, FR-046, FR-078)', () {
    test(
      'a lecture needs title + subject to save, and a doctor to publish',
      () {
        const empty = ContentDraft(type: ContentType.lecture);
        expect(empty.missingForSave(), {DraftField.title, DraftField.subject});

        const noDoctor = ContentDraft(
          type: ContentType.lecture,
          title: 'Intro',
          subjectId: 's1',
        );
        expect(noDoctor.missingForSave(), isEmpty);
        expect(noDoctor.missingForPublish(), {DraftField.doctor});

        final complete = noDoctor.copyWith(doctorId: const Nullable('d1'));
        expect(complete.missingForPublish(), isEmpty);
      },
    );

    test(
      'an exam needs year, term and session type to publish; doctor optional',
      () {
        const exam = ContentDraft(
          type: ContentType.exam,
          title: 'Final 2024',
          subjectId: 's1',
        );
        expect(exam.missingForPublish(), {
          DraftField.examYear,
          DraftField.term,
          DraftField.examType,
        });
        final complete = exam.copyWith(
          examYear: const Nullable(2024),
          termId: const Nullable('t1'),
          examTypeId: const Nullable('e1'),
        );
        expect(complete.missingForPublish(), isEmpty);
      },
    );

    test('toFields only sends fields relevant to the type', () {
      const lecture = ContentDraft(
        type: ContentType.lecture,
        title: '  Intro  ',
        subjectId: 's1',
        lectureNumber: 3,
        examYear: 2020,
      );
      final fields = lecture.toFields();
      expect(fields['title'], 'Intro');
      expect(fields['lectureNumber'], 3);
      expect(fields['examYear'], isNull);
      expect(fields['description'], isNull);
    });

    test('copyWith distinguishes "unchanged" from "cleared"', () {
      const d = ContentDraft(type: ContentType.lecture, doctorId: 'd1');
      expect(d.copyWith(title: 'x').doctorId, 'd1');
      expect(d.copyWith(doctorId: const Nullable(null)).doctorId, isNull);
    });
  });

  group('Upload pre-check (FR-043)', () {
    const config = ClientConfig(
      maxUploadSizeMb: 2,
      allowedExtensions: ['pdf', 'png'],
      requireContentReview: false,
      watermarkEnabled: true,
      screenCaptureProtection: true,
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

  group('ContentQuery / ExamFilter', () {
    test('counts active filters and drops empty values from the query', () {
      const q = ContentQuery(text: ' ', type: ContentType.exam, yearId: 'y');
      expect(q.activeFilterCount, 2);
      expect(q.isEmpty, isFalse);
      expect(const ContentQuery().isEmpty, isTrue);
      expect(q.toQuery()['q'], '');
    });

    test('value equality makes them safe provider family keys', () {
      expect(
        const ExamFilter(examYear: 2024),
        equals(const ExamFilter(examYear: 2024)),
      );
      expect(
        const ExamFilter().copyWith(termId: const Nullable('t')).activeCount,
        1,
      );
    });
  });
}
