import '../../../core/models/json.dart';
import 'content.dart';

/// Mandatory classification fields, per content type (FR-036, FR-046, FR-078).
enum DraftField {
  title,
  subject,
  doctor,
  category,
  examYear,
  term,
  examType,
  file,
}

/// Editable metadata of a content item, used for create and edit.
class ContentDraft {
  const ContentDraft({
    required this.type,
    this.title = '',
    this.description = '',
    this.universityId,
    this.facultyId,
    this.yearId,
    this.subjectId,
    this.doctorId,
    this.lectureNumber,
    this.categoryId,
    this.examYear,
    this.termId,
    this.examTypeId,
  });

  factory ContentDraft.fromContent(Content c) => ContentDraft(
    type: c.type,
    title: c.title,
    description: c.description ?? '',
    universityId: c.classification.universityId,
    facultyId: c.classification.facultyId,
    yearId: c.classification.yearId,
    subjectId: c.subjectId,
    doctorId: c.doctorId,
    lectureNumber: c.lectureNumber,
    categoryId: c.categoryId,
    examYear: c.examYear,
    termId: c.termId,
    examTypeId: c.examTypeId,
  );

  final ContentType type;
  final String title;
  final String description;

  /// University/faculty/year only drive the cascading pickers; the server
  /// derives the full path from the subject.
  final String? universityId;
  final String? facultyId;
  final String? yearId;
  final String? subjectId;
  final String? doctorId;
  final int? lectureNumber;

  /// Lecture classification (theory / practical…), required to publish.
  final String? categoryId;
  final int? examYear;
  final String? termId;
  final String? examTypeId;

  /// Fields required before the item may be saved at all.
  Set<DraftField> missingForSave() => {
    if (title.trim().isEmpty) DraftField.title,
    if (subjectId == null) DraftField.subject,
  };

  /// Fields required before the item may be published (FR-078).
  Set<DraftField> missingForPublish() => {
    ...missingForSave(),
    if (type == ContentType.lecture) ...{
      if (doctorId == null) DraftField.doctor,
      if (categoryId == null) DraftField.category,
    },
    if (type == ContentType.exam) ...{
      if (examYear == null) DraftField.examYear,
      if (termId == null) DraftField.term,
      if (examTypeId == null) DraftField.examType,
    },
  };

  /// Payload for create (multipart fields) and PATCH, in the API's field
  /// names. Fields of the other content type are always null: the server
  /// rejects them.
  Json toFields() {
    final lecture = type == ContentType.lecture;
    return {
      'kind': type.name,
      'title': title.trim(),
      'description': description.trim(),
      'course': intId(subjectId),
      'instructor': intId(doctorId),
      'lecture_number': lecture ? lectureNumber : null,
      'category': lecture ? intId(categoryId) : null,
      'exam_year': lecture ? null : examYear,
      'exam_type': lecture ? null : intId(examTypeId),
      'semester': lecture ? null : intId(termId),
    };
  }

  ContentDraft copyWith({
    String? title,
    String? description,
    Nullable<String>? universityId,
    Nullable<String>? facultyId,
    Nullable<String>? yearId,
    Nullable<String>? subjectId,
    Nullable<String>? doctorId,
    Nullable<int>? lectureNumber,
    Nullable<String>? categoryId,
    Nullable<int>? examYear,
    Nullable<String>? termId,
    Nullable<String>? examTypeId,
  }) => ContentDraft(
    type: type,
    title: title ?? this.title,
    description: description ?? this.description,
    universityId: universityId == null ? this.universityId : universityId.value,
    facultyId: facultyId == null ? this.facultyId : facultyId.value,
    yearId: yearId == null ? this.yearId : yearId.value,
    subjectId: subjectId == null ? this.subjectId : subjectId.value,
    doctorId: doctorId == null ? this.doctorId : doctorId.value,
    lectureNumber: lectureNumber == null
        ? this.lectureNumber
        : lectureNumber.value,
    categoryId: categoryId == null ? this.categoryId : categoryId.value,
    examYear: examYear == null ? this.examYear : examYear.value,
    termId: termId == null ? this.termId : termId.value,
    examTypeId: examTypeId == null ? this.examTypeId : examTypeId.value,
  );
}

/// Filters for the library/admin content manager (FR-061, FR-065).
class ManageQuery {
  const ManageQuery({this.text = '', this.type, this.status});

  final String text;
  final ContentType? type;
  final ContentStatus? status;

  /// Query of `manage/contents/`.
  Map<String, dynamic> toQuery() => {
    'search': text.trim(),
    'kind': type?.name,
    'status': status?.apiValue,
  };

  ManageQuery copyWith({
    String? text,
    Nullable<ContentType>? type,
    Nullable<ContentStatus>? status,
  }) => ManageQuery(
    text: text ?? this.text,
    type: type == null ? this.type : type.value,
    status: status == null ? this.status : status.value,
  );

  @override
  bool operator ==(Object other) =>
      other is ManageQuery &&
      other.text == text &&
      other.type == type &&
      other.status == status;

  @override
  int get hashCode => Object.hash(text, type, status);
}
