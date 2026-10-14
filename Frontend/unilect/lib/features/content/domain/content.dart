import '../../../core/models/json.dart';
import '../../academic/domain/academic_models.dart';

enum ContentType { lecture, exam }

/// Publication lifecycle (FR-042, FR-065, FR-066).
enum ContentStatus {
  draft('draft'),
  pendingReview('pending_review'),
  published('published'),
  archived('archived');

  const ContentStatus(this.apiValue);

  final String apiValue;

  static ContentStatus fromApi(Object? value) => values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => ContentStatus.draft,
  );
}

/// Current file of a content item. Only PDFs and images are accepted by the
/// server, so every stored file can be shown in the in-app viewer.
class ContentFile {
  const ContentFile({
    required this.mimeType,
    required this.sizeBytes,
    required this.version,
    this.extension,
    this.pageCount,
    this.originalName,
    this.uploadedAt,
  });

  factory ContentFile.fromJson(Json json) => ContentFile(
    mimeType: json['mime_type'] as String,
    sizeBytes: json['size_bytes'] as int,
    version: json['version'] as int? ?? 1,
    extension: json['extension'] as String?,
    pageCount: json['page_count'] as int?,
    originalName: json['original_name'] as String?,
    uploadedAt: parseDateOrNull(json['uploaded_at']),
  );

  final String mimeType;
  final int sizeBytes;
  final int version;
  final String? extension;
  final int? pageCount;

  /// Manage views only.
  final String? originalName;
  final DateTime? uploadedAt;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
  bool get isViewable => isPdf || isImage;
}

/// Denormalized academic path of a content item (FR-033, FR-037).
class Classification {
  const Classification({
    required this.universityId,
    required this.universityName,
    required this.facultyId,
    required this.facultyName,
    required this.yearId,
    required this.yearName,
    required this.subjectName,
    this.doctorName,
    this.termName,
    this.examTypeName,
    this.categoryName,
  });

  final String universityId;
  final String universityName;
  final String facultyId;
  final String facultyName;
  final String yearId;
  final String yearName;
  final String subjectName;
  final String? doctorName;
  final String? termName;
  final String? examTypeName;
  final String? categoryName;
}

class Content {
  const Content({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.subjectId,
    required this.classification,
    required this.createdAt,
    required this.updatedAt,
    this.file,
    this.description,
    this.doctorId,
    this.lectureNumber,
    this.categoryId,
    this.examYear,
    this.termId,
    this.examTypeId,
    this.isFavorite = false,
    this.reviewNote,
    this.publishedAt,
    this.watermarkText,
    this.libraryName,
  });

  /// Parses both `catalog/contents/` (students: published only, with `file`,
  /// `is_favorite`, `watermark_text`) and `manage/contents/` (with `status`,
  /// `review_note`, `current_file`, `library`, timestamps).
  factory Content.fromJson(Json json) {
    Json? ref(String key) => json[key] as Json?;
    String? name(String key) => ref(key)?['name'] as String?;
    final instructor = ref('instructor');
    final fileJson = (json['current_file'] ?? json['file']) as Json?;
    final publishedAt = parseDateOrNull(json['published_at']);
    final createdAt =
        parseDateOrNull(json['created_at']) ?? publishedAt ?? DateTime.now();
    return Content(
      id: idOf(json['id']),
      type: enumByName(ContentType.values, json['kind'], ContentType.lecture),
      title: json['title'] as String,
      status: json.containsKey('status')
          ? ContentStatus.fromApi(json['status'])
          : ContentStatus.published,
      subjectId: idOf(ref('course')!['id']),
      classification: Classification(
        universityId: idOf(ref('university')!['id']),
        universityName: name('university')!,
        facultyId: idOf(ref('faculty')!['id']),
        facultyName: name('faculty')!,
        yearId: idOf(ref('level')!['id']),
        yearName: name('level')!,
        subjectName: name('course')!,
        doctorName: instructor == null
            ? null
            : Doctor.displayName(
                instructor['title'] as String? ?? '',
                instructor['full_name'] as String,
              ),
        termName: name('semester'),
        examTypeName: name('exam_type'),
        categoryName: name('category'),
      ),
      file: fileJson == null ? null : ContentFile.fromJson(fileJson),
      createdAt: createdAt,
      updatedAt: parseDateOrNull(json['updated_at']) ?? createdAt,
      description: textOrNull(json['description']),
      doctorId: idOrNull(instructor?['id']),
      lectureNumber: json['lecture_number'] as int?,
      categoryId: idOrNull(ref('category')?['id']),
      examYear: json['exam_year'] as int?,
      termId: idOrNull(ref('semester')?['id']),
      examTypeId: idOrNull(ref('exam_type')?['id']),
      isFavorite: json['is_favorite'] as bool? ?? false,
      reviewNote: textOrNull(json['review_note']),
      publishedAt: publishedAt,
      watermarkText: json['watermark_text'] as String?,
      libraryName: name('library'),
    );
  }

  final String id;
  final ContentType type;
  final String title;
  final ContentStatus status;
  final String subjectId;
  final Classification classification;

  /// Null for a draft saved before its file was uploaded.
  final ContentFile? file;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? doctorId;
  final int? lectureNumber;
  final String? categoryId;
  final int? examYear;
  final String? termId;
  final String? examTypeId;
  final bool isFavorite;
  final String? reviewNote;
  final DateTime? publishedAt;

  /// Non-identifying viewer code to overlay on the file (FR-057).
  final String? watermarkText;
  final String? libraryName;

  Content copyWith({bool? isFavorite}) => Content(
    id: id,
    type: type,
    title: title,
    status: status,
    subjectId: subjectId,
    classification: classification,
    file: file,
    createdAt: createdAt,
    updatedAt: updatedAt,
    description: description,
    doctorId: doctorId,
    lectureNumber: lectureNumber,
    categoryId: categoryId,
    examYear: examYear,
    termId: termId,
    examTypeId: examTypeId,
    isFavorite: isFavorite ?? this.isFavorite,
    reviewNote: reviewNote,
    publishedAt: publishedAt,
    watermarkText: watermarkText,
    libraryName: libraryName,
  );
}

/// One stored version of a content file (FR-041).
class ContentVersion {
  const ContentVersion({
    required this.version,
    required this.originalName,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.isCurrent,
  });

  factory ContentVersion.fromJson(Json json) => ContentVersion(
    version: json['version'] as int,
    originalName: json['original_name'] as String? ?? '',
    sizeBytes: json['size_bytes'] as int,
    uploadedAt: parseDate(json['uploaded_at']),
    uploadedBy: json['uploaded_by'] as String? ?? '—',
    isCurrent: json['is_current'] as bool? ?? false,
  );

  final int version;
  final String originalName;
  final int sizeBytes;
  final DateTime uploadedAt;

  /// Email of the uploader.
  final String uploadedBy;
  final bool isCurrent;
}

/// Content counts per status within the caller's scope (FR-062).
class ContentStats {
  const ContentStats({
    this.published = 0,
    this.draft = 0,
    this.pendingReview = 0,
    this.archived = 0,
  });

  /// `{by_status: {draft, pending_review, published, archived}, …}`.
  factory ContentStats.fromJson(Json json) {
    final s = json['by_status'] as Json? ?? const {};
    int n(ContentStatus status) => s[status.apiValue] as int? ?? 0;
    return ContentStats(
      published: n(ContentStatus.published),
      draft: n(ContentStatus.draft),
      pendingReview: n(ContentStatus.pendingReview),
      archived: n(ContentStatus.archived),
    );
  }

  final int published;
  final int draft;
  final int pendingReview;
  final int archived;
}

/// Student search/browse filters (FR-031, FR-032, FR-050).
class ContentQuery {
  const ContentQuery({
    this.text = '',
    this.type,
    this.universityId,
    this.facultyId,
    this.yearId,
    this.subjectId,
    this.doctorId,
  });

  final String text;
  final ContentType? type;
  final String? universityId;
  final String? facultyId;
  final String? yearId;
  final String? subjectId;
  final String? doctorId;

  int get activeFilterCount => [
    type,
    universityId,
    facultyId,
    yearId,
    subjectId,
    doctorId,
  ].where((e) => e != null).length;

  bool get isEmpty => text.trim().isEmpty && activeFilterCount == 0;

  /// Query of `catalog/contents/`.
  Map<String, dynamic> toQuery() => {
    'search': text.trim(),
    'kind': type?.name,
    'university': universityId,
    'faculty': facultyId,
    'level': yearId,
    'course': subjectId,
    'instructor': doctorId,
  };

  @override
  bool operator ==(Object other) =>
      other is ContentQuery &&
      other.text == text &&
      other.type == type &&
      other.universityId == universityId &&
      other.facultyId == facultyId &&
      other.yearId == yearId &&
      other.subjectId == subjectId &&
      other.doctorId == doctorId;

  @override
  int get hashCode => Object.hash(
    text,
    type,
    universityId,
    facultyId,
    yearId,
    subjectId,
    doctorId,
  );
}

class ExamFilter {
  const ExamFilter({
    this.examYear,
    this.termId,
    this.examTypeId,
    this.doctorId,
  });

  final int? examYear;
  final String? termId;
  final String? examTypeId;
  final String? doctorId;

  /// Query of `catalog/contents/?kind=exam`.
  Map<String, dynamic> toQuery() => {
    'exam_year': examYear,
    'semester': termId,
    'exam_type': examTypeId,
    'instructor': doctorId,
  };

  int get activeCount =>
      [examYear, termId, examTypeId, doctorId].where((e) => e != null).length;

  ExamFilter copyWith({
    Nullable<int>? examYear,
    Nullable<String>? termId,
    Nullable<String>? examTypeId,
    Nullable<String>? doctorId,
  }) => ExamFilter(
    examYear: examYear == null ? this.examYear : examYear.value,
    termId: termId == null ? this.termId : termId.value,
    examTypeId: examTypeId == null ? this.examTypeId : examTypeId.value,
    doctorId: doctorId == null ? this.doctorId : doctorId.value,
  );

  @override
  bool operator ==(Object other) =>
      other is ExamFilter &&
      other.examYear == examYear &&
      other.termId == termId &&
      other.examTypeId == examTypeId &&
      other.doctorId == doctorId;

  @override
  int get hashCode => Object.hash(examYear, termId, examTypeId, doctorId);
}
