import '../../../core/models/json.dart';

/// The managed academic structure kinds (FR-016..022, FR-048) and the admin
/// API resource of each. [parent] is the kind used to scope listings.
enum StructureKind {
  universities('universities', null),
  faculties('faculties', universities),
  years('levels', faculties),
  terms('semesters', faculties),
  specializations('specializations', faculties),
  subjects('courses', faculties),
  doctors('instructors', null),
  lectureCategories('lecture-categories', null),
  examTypes('exam-types', null);

  const StructureKind(this.apiPath, this.parent);

  /// Resource under `admin/` (and `catalog/` for read access).
  final String apiPath;
  final StructureKind? parent;

  /// Query parameter that scopes a listing to its parent.
  String? get parentParam => switch (parent) {
    universities => 'university',
    faculties => 'faculty',
    _ => null,
  };

  AcademicItem parse(Json json) => switch (this) {
    universities ||
    examTypes ||
    lectureCategories => AcademicItem.fromJson(json),
    faculties => Faculty.fromJson(json),
    years => AcademicYear.fromJson(json),
    terms => Term.fromJson(json),
    specializations => Specialization.fromJson(json),
    subjects => Subject.fromJson(json),
    doctors => Doctor.fromJson(json),
  };
}

/// Common shape of every structure item.
class AcademicItem {
  const AcademicItem({
    required this.id,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  factory AcademicItem.fromJson(Json json) => AcademicItem(
    id: idOf(json['id']),
    name: json['name'] as String,
    isActive: json['is_active'] as bool? ?? true,
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  final String id;
  final String name;

  /// Catalog (student) responses only contain active items; admin responses
  /// carry the flag.
  final bool isActive;
  final int sortOrder;
}

typedef University = AcademicItem;
typedef ExamType = AcademicItem;

/// Lecture classification such as theory / practical (required to publish a
/// lecture).
typedef LectureCategory = AcademicItem;

class Faculty extends AcademicItem {
  const Faculty({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.universityId,
  });

  factory Faculty.fromJson(Json json) {
    final base = AcademicItem.fromJson(json);
    return Faculty(
      id: base.id,
      name: base.name,
      isActive: base.isActive,
      sortOrder: base.sortOrder,
      universityId: idOf(json['university']),
    );
  }

  final String universityId;
}

/// A study year ("level") of a faculty.
class AcademicYear extends AcademicItem {
  const AcademicYear({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.facultyId,
    required this.level,
  });

  factory AcademicYear.fromJson(Json json) {
    final base = AcademicItem.fromJson(json);
    return AcademicYear(
      id: base.id,
      name: base.name,
      isActive: base.isActive,
      sortOrder: base.sortOrder,
      facultyId: idOf(json['faculty']),
      level: json['number'] as int? ?? 1,
    );
  }

  final String facultyId;

  /// Unique per faculty.
  final int level;
}

/// A semester ("term"), defined per faculty.
class Term extends AcademicItem {
  const Term({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.facultyId,
    required this.number,
  });

  factory Term.fromJson(Json json) {
    final base = AcademicItem.fromJson(json);
    return Term(
      id: base.id,
      name: base.name,
      isActive: base.isActive,
      sortOrder: base.sortOrder,
      facultyId: idOf(json['faculty']),
      number: json['number'] as int? ?? 1,
    );
  }

  final String facultyId;

  /// Unique per faculty.
  final int number;
}

class Specialization extends AcademicItem {
  const Specialization({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.facultyId,
  });

  factory Specialization.fromJson(Json json) {
    final base = AcademicItem.fromJson(json);
    return Specialization(
      id: base.id,
      name: base.name,
      isActive: base.isActive,
      sortOrder: base.sortOrder,
      facultyId: idOf(json['faculty']),
    );
  }

  final String facultyId;
}

/// A course ("subject").
class Subject extends AcademicItem {
  const Subject({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.facultyId,
    required this.yearId,
    this.universityId,
    this.termId,
    this.code,
    this.specializationIds = const [],
  });

  factory Subject.fromJson(Json json) {
    final base = AcademicItem.fromJson(json);
    return Subject(
      id: base.id,
      name: base.name,
      isActive: base.isActive,
      sortOrder: base.sortOrder,
      facultyId: idOf(json['faculty']),
      yearId: idOf(json['level']),
      universityId: idOrNull(json['university']),
      termId: idOrNull(json['semester']),
      code: textOrNull(json['code']),
      specializationIds: parseStringList(json['specializations']),
    );
  }

  final String facultyId;
  final String yearId;
  final String? universityId;

  /// Optional semester the course is taught in.
  final String? termId;
  final String? code;

  /// Empty = common to every specialization of the faculty.
  final List<String> specializationIds;
}

/// An instructor ("doctor"), linked to the courses they teach.
class Doctor extends AcademicItem {
  const Doctor({
    required super.id,
    required super.name,
    required super.isActive,
    required super.sortOrder,
    required this.fullName,
    this.title = '',
    this.universityId,
    this.subjectIds = const [],
  });

  factory Doctor.fromJson(Json json, {List<String> subjectIds = const []}) {
    final fullName = json['full_name'] as String;
    final title = json['title'] as String? ?? '';
    return Doctor(
      id: idOf(json['id']),
      name: displayName(title, fullName),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      fullName: fullName,
      title: title,
      universityId: idOrNull(json['university']),
      subjectIds: subjectIds,
    );
  }

  static String displayName(String title, String fullName) =>
      '$title $fullName'.trim();

  final String fullName;

  /// Honorific such as «د.».
  final String title;
  final String? universityId;

  /// Linked courses (admin views only).
  final List<String> subjectIds;

  Doctor withSubjects(List<String> ids) => Doctor(
    id: id,
    name: name,
    isActive: isActive,
    sortOrder: sortOrder,
    fullName: fullName,
    title: title,
    universityId: universityId,
    subjectIds: ids,
  );
}

/// A course ↔ instructor link (`admin/course-instructors/`).
class CourseInstructorLink {
  const CourseInstructorLink({
    required this.id,
    required this.subjectId,
    required this.doctorId,
  });

  factory CourseInstructorLink.fromJson(Json json) => CourseInstructorLink(
    id: idOf(json['id']),
    subjectId: idOf(json['course']),
    doctorId: idOf(json['instructor']),
  );

  final String id;
  final String subjectId;
  final String doctorId;
}

/// A content provider and its academic scope (FR-059, FR-060).
class Library {
  const Library({
    required this.id,
    required this.name,
    required this.isActive,
    this.contactEmail,
    this.contactPhone,
    this.universityIds = const [],
    this.facultyIds = const [],
    this.subjectIds = const [],
    this.staffCount = 0,
  });

  factory Library.fromJson(Json json) => Library(
    id: idOf(json['id']),
    name: json['name'] as String,
    isActive: json['is_active'] as bool? ?? true,
    contactEmail: textOrNull(json['contact_email']),
    contactPhone: textOrNull(json['contact_phone']),
    universityIds: parseStringList(json['scope_universities']),
    facultyIds: parseStringList(json['scope_faculties']),
    subjectIds: parseStringList(json['scope_courses']),
    staffCount: json['staff_count'] as int? ?? 0,
  );

  final String id;
  final String name;
  final bool isActive;
  final String? contactEmail;
  final String? contactPhone;

  /// Scope = union of whole universities, whole faculties and single courses.
  final List<String> universityIds;
  final List<String> facultyIds;
  final List<String> subjectIds;
  final int staffCount;

  bool get hasScope =>
      universityIds.isNotEmpty ||
      facultyIds.isNotEmpty ||
      subjectIds.isNotEmpty;
}
