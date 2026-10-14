import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../domain/academic_models.dart';

/// Read access to the academic catalog (student browse, library pickers) and
/// admin management of every structure kind.
///
/// Catalog lists only contain active items whose ancestors are active
/// (FR-024..028). With [inScope] a library account only receives the nodes
/// that contain courses inside its scope (FR-060); other roles ignore it.
class AcademicRepository {
  AcademicRepository(this._api);

  final ApiClient _api;

  Future<List<University>> universities({bool inScope = false}) => _api.getAll(
    '/catalog/universities/',
    AcademicItem.fromJson,
    query: _scope(inScope),
  );

  Future<List<Faculty>> faculties(
    String universityId, {
    bool inScope = false,
  }) => _api.getAll(
    '/catalog/faculties/',
    Faculty.fromJson,
    query: {'university': universityId, ..._scope(inScope)},
  );

  Future<List<AcademicYear>> years(String facultyId, {bool inScope = false}) =>
      _api.getAll(
        '/catalog/levels/',
        AcademicYear.fromJson,
        query: {'faculty': facultyId, ..._scope(inScope)},
      );

  Future<List<Specialization>> specializations(String facultyId) => _api.getAll(
    '/catalog/specializations/',
    Specialization.fromJson,
    query: {'faculty': facultyId},
  );

  /// Courses of a year. With [specializationId], courses common to every
  /// specialization are included too.
  Future<List<Subject>> subjects(
    String yearId, {
    String? specializationId,
    bool inScope = false,
  }) => _api.getAll(
    '/catalog/courses/',
    Subject.fromJson,
    query: {
      'level': yearId,
      'specialization': specializationId,
      ..._scope(inScope),
    },
  );

  Future<Subject> subject(String id) async =>
      Subject.fromJson(await _api.get<Json>('/catalog/courses/$id/'));

  /// Active instructors of a course, in the admin-defined order.
  Future<List<Doctor>> doctors(String subjectId) =>
      _api.getList('/catalog/courses/$subjectId/instructors/', Doctor.fromJson);

  Future<List<Term>> terms(String facultyId) => _api.getAll(
    '/catalog/semesters/',
    Term.fromJson,
    query: {'faculty': facultyId},
  );

  Future<List<ExamType>> examTypes() =>
      _api.getList('/catalog/exam-types/', AcademicItem.fromJson);

  Future<List<LectureCategory>> lectureCategories() =>
      _api.getList('/catalog/lecture-categories/', AcademicItem.fromJson);

  static Map<String, dynamic> _scope(bool inScope) =>
      inScope ? const {'in_scope': 'true'} : const {};

  // ── Admin management ────────────────────────────────────────────────────

  /// Every item of [kind] including inactive ones (FR-016..022). Doctors come
  /// with their linked courses.
  Future<List<AcademicItem>> adminList(
    StructureKind kind, {
    String? parentId,
  }) async {
    final param = kind.parentParam;
    final items = await _api.getAll(
      '/admin/${kind.apiPath}/',
      kind.parse,
      query: {?param: parentId},
    );
    if (kind != StructureKind.doctors) return items;
    final links = await courseLinks();
    return [
      for (final d in items.cast<Doctor>())
        d.withSubjects([
          for (final l in links)
            if (l.doctorId == d.id) l.subjectId,
        ]),
    ];
  }

  /// [body] uses the API field names of the resource (`name`, `is_active`,
  /// `faculty`, `number`, …).
  Future<AcademicItem> adminCreate(StructureKind kind, Json body) async =>
      kind.parse(await _api.post<Json>('/admin/${kind.apiPath}/', body: body));

  Future<AcademicItem> adminUpdate(
    StructureKind kind,
    String id,
    Json body,
  ) async => kind.parse(
    await _api.patch<Json>('/admin/${kind.apiPath}/$id/', body: body),
  );

  /// Persists the display order (FR-023) as each item's `sort_order`.
  Future<void> adminReorder(StructureKind kind, List<String> ids) =>
      Future.wait([
        for (final (i, id) in ids.indexed)
          _api.patch<Json>(
            '/admin/${kind.apiPath}/$id/',
            body: {'sort_order': i + 1},
          ),
      ]);

  /// Every course of a university (all faculties), including inactive ones.
  Future<List<Subject>> adminUniversitySubjects(String universityId) =>
      _api.getAll(
        '/admin/courses/',
        Subject.fromJson,
        query: {'university': universityId},
      );

  Future<List<CourseInstructorLink>> courseLinks({String? doctorId}) =>
      _api.getAll(
        '/admin/course-instructors/',
        CourseInstructorLink.fromJson,
        query: {'instructor': doctorId},
      );

  /// Makes [subjectIds] the exact set of courses the doctor teaches.
  Future<void> setDoctorSubjects(
    String doctorId,
    Set<String> subjectIds,
  ) async {
    final current = await courseLinks(doctorId: doctorId);
    final linked = {for (final l in current) l.subjectId};
    for (final l in current) {
      if (!subjectIds.contains(l.subjectId)) {
        await _api.delete('/admin/course-instructors/${l.id}/');
      }
    }
    for (final id in subjectIds.difference(linked)) {
      await _api.post<Json>(
        '/admin/course-instructors/',
        body: {'course': intId(id), 'instructor': intId(doctorId)},
      );
    }
  }

  // ── Libraries ──

  Future<List<Library>> libraries() =>
      _api.getAll('/admin/libraries/', Library.fromJson);

  Future<Library> saveLibrary({
    String? id,
    required String name,
    required bool isActive,
    String? contactEmail,
    String? contactPhone,
    required Set<String> universityIds,
    required Set<String> facultyIds,
  }) async {
    final body = {
      'name': name.trim(),
      'is_active': isActive,
      'contact_email': contactEmail?.trim() ?? '',
      'contact_phone': contactPhone?.trim() ?? '',
      'scope_universities': [for (final u in universityIds) intId(u)],
      'scope_faculties': [for (final f in facultyIds) intId(f)],
    };
    return Library.fromJson(
      id == null
          ? await _api.post<Json>('/admin/libraries/', body: body)
          : await _api.patch<Json>('/admin/libraries/$id/', body: body),
    );
  }
}
