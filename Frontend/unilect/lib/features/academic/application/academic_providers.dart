import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../domain/academic_models.dart';

/// Read-side providers of the academic tree. Students receive active items
/// only; library accounts additionally only see the part of the tree that
/// contains their scope (FR-060) — both filtered by the server.

final _inScopeProvider = Provider<bool>(
  (ref) =>
      ref.watch(currentUserProvider.select((u) => u?.role)) == UserRole.library,
);

final universitiesProvider = FutureProvider.autoDispose<List<University>>(
  (ref) => ref
      .watch(academicRepositoryProvider)
      .universities(inScope: ref.watch(_inScopeProvider)),
);

final facultiesProvider = FutureProvider.autoDispose
    .family<List<Faculty>, String>(
      (ref, universityId) => ref
          .watch(academicRepositoryProvider)
          .faculties(universityId, inScope: ref.watch(_inScopeProvider)),
    );

final yearsProvider = FutureProvider.autoDispose
    .family<List<AcademicYear>, String>(
      (ref, facultyId) => ref
          .watch(academicRepositoryProvider)
          .years(facultyId, inScope: ref.watch(_inScopeProvider)),
    );

final specializationsProvider = FutureProvider.autoDispose
    .family<List<Specialization>, String>(
      (ref, facultyId) =>
          ref.watch(academicRepositoryProvider).specializations(facultyId),
    );

final subjectsProvider = FutureProvider.autoDispose
    .family<List<Subject>, ({String yearId, String? specializationId})>(
      (ref, args) => ref
          .watch(academicRepositoryProvider)
          .subjects(
            args.yearId,
            specializationId: args.specializationId,
            inScope: ref.watch(_inScopeProvider),
          ),
    );

final subjectProvider = FutureProvider.autoDispose.family<Subject, String>(
  (ref, id) => ref.watch(academicRepositoryProvider).subject(id),
);

final doctorsProvider = FutureProvider.autoDispose.family<List<Doctor>, String>(
  (ref, subjectId) => ref.watch(academicRepositoryProvider).doctors(subjectId),
);

/// Semesters of a faculty.
final termsProvider = FutureProvider.autoDispose.family<List<Term>, String>(
  (ref, facultyId) => ref.watch(academicRepositoryProvider).terms(facultyId),
);

final examTypesProvider = FutureProvider.autoDispose<List<ExamType>>(
  (ref) => ref.watch(academicRepositoryProvider).examTypes(),
);

final lectureCategoriesProvider =
    FutureProvider.autoDispose<List<LectureCategory>>(
      (ref) => ref.watch(academicRepositoryProvider).lectureCategories(),
    );
