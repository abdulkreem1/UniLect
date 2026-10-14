import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/models/json.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../academic/application/academic_providers.dart';
import '../../../academic/domain/academic_models.dart';
import '../../../content/domain/content.dart';
import '../../../content/domain/content_draft.dart';

/// Cascading university → faculty → year → subject → doctor pickers
/// (FR-037, FR-046). Lists come from the server already restricted to the
/// library's scope (FR-060).
class ClassificationFields extends ConsumerWidget {
  const ClassificationFields({
    super.key,
    required this.draft,
    required this.onChanged,
    this.showErrors = false,
  });

  final ContentDraft draft;
  final ValueChanged<ContentDraft> onChanged;
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    List<PickerOption<String>> opts<T>(
      AsyncValue<List<T>>? v,
      String Function(T) id,
      String Function(T) name,
    ) => [for (final e in v?.value ?? <T>[]) PickerOption(id(e), name(e))];

    final unis = ref.watch(universitiesProvider);
    final facs = draft.universityId == null
        ? null
        : ref.watch(facultiesProvider(draft.universityId!));
    final years = draft.facultyId == null
        ? null
        : ref.watch(yearsProvider(draft.facultyId!));
    final subjects = draft.yearId == null
        ? null
        : ref.watch(
            subjectsProvider((yearId: draft.yearId!, specializationId: null)),
          );
    final doctors = draft.subjectId == null
        ? null
        : ref.watch(doctorsProvider(draft.subjectId!));

    final doctorRequired = draft.type == ContentType.lecture;
    String? requiredError(Object? v) =>
        showErrors && v == null ? l.fieldRequired : null;

    return Column(
      children: [
        PickerField<String>(
          label: l.university,
          icon: Icons.account_balance_outlined,
          loading: unis.isLoading,
          options: opts(unis, (e) => e.id, (e) => e.name),
          value: draft.universityId,
          errorText: requiredError(draft.universityId),
          onChanged: (v) => onChanged(
            draft.copyWith(
              universityId: Nullable(v),
              facultyId: const Nullable(null),
              yearId: const Nullable(null),
              subjectId: const Nullable(null),
              doctorId: const Nullable(null),
              termId: const Nullable(null),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: l.faculty,
          icon: Icons.domain_outlined,
          enabled: facs != null,
          loading: facs?.isLoading ?? false,
          options: opts(facs, (e) => e.id, (e) => e.name),
          value: draft.facultyId,
          errorText: requiredError(draft.facultyId),
          onChanged: (v) => onChanged(
            draft.copyWith(
              facultyId: Nullable(v),
              yearId: const Nullable(null),
              subjectId: const Nullable(null),
              doctorId: const Nullable(null),
              termId: const Nullable(null),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: l.year,
          icon: Icons.layers_outlined,
          enabled: years != null,
          loading: years?.isLoading ?? false,
          options: opts(years, (e) => e.id, (e) => e.name),
          value: draft.yearId,
          errorText: requiredError(draft.yearId),
          onChanged: (v) => onChanged(
            draft.copyWith(
              yearId: Nullable(v),
              subjectId: const Nullable(null),
              doctorId: const Nullable(null),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: l.subject,
          icon: Icons.menu_book_outlined,
          enabled: subjects != null,
          loading: subjects?.isLoading ?? false,
          options: opts(subjects, (e) => e.id, (e) => e.name),
          value: draft.subjectId,
          errorText: requiredError(draft.subjectId),
          onChanged: (v) => onChanged(
            draft.copyWith(
              subjectId: Nullable(v),
              doctorId: const Nullable(null),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: doctorRequired ? l.doctor : '${l.doctor} (${l.optional})',
          icon: Icons.person_outline_rounded,
          enabled: doctors != null,
          allowClear: !doctorRequired,
          loading: doctors?.isLoading ?? false,
          options: opts(doctors, (e) => e.id, (e) => e.name),
          value: draft.doctorId,
          errorText: doctorRequired ? requiredError(draft.doctorId) : null,
          onChanged: (v) => onChanged(draft.copyWith(doctorId: Nullable(v))),
        ),
      ],
    );
  }
}

/// Lecture-specific field: the category (theory / practical…), required to
/// publish.
class LectureFields extends ConsumerWidget {
  const LectureFields({
    super.key,
    required this.draft,
    required this.onChanged,
    this.showErrors = false,
  });

  final ContentDraft draft;
  final ValueChanged<ContentDraft> onChanged;
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final categories = ref.watch(lectureCategoriesProvider);
    return PickerField<String>(
      label: l.category,
      icon: Icons.category_outlined,
      loading: categories.isLoading,
      options: [
        for (final c in categories.value ?? const <AcademicItem>[])
          PickerOption(c.id, c.name),
      ],
      value: draft.categoryId,
      errorText: showErrors && draft.categoryId == null
          ? l.fieldRequired
          : null,
      onChanged: (v) => onChanged(draft.copyWith(categoryId: Nullable(v))),
    );
  }
}

/// Exam-specific fields: year, semester of the course's faculty, session
/// type (FR-046..048).
class ExamFields extends ConsumerWidget {
  const ExamFields({
    super.key,
    required this.draft,
    required this.onChanged,
    this.showErrors = false,
  });

  final ContentDraft draft;
  final ValueChanged<ContentDraft> onChanged;
  final bool showErrors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final terms = draft.facultyId == null
        ? null
        : ref.watch(termsProvider(draft.facultyId!));
    final types = ref.watch(examTypesProvider);
    final thisYear = DateTime.now().year;
    String? err(Object? v) => showErrors && v == null ? l.fieldRequired : null;
    return Column(
      children: [
        PickerField<int>(
          label: l.examYear,
          icon: Icons.event_outlined,
          options: [
            for (var y = thisYear + 1; y >= thisYear - 25; y--)
              PickerOption(y, '$y'),
          ],
          value: draft.examYear,
          errorText: err(draft.examYear),
          onChanged: (v) => onChanged(draft.copyWith(examYear: Nullable(v))),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: l.term,
          icon: Icons.date_range_outlined,
          enabled: terms != null,
          loading: terms?.isLoading ?? false,
          options: [
            for (final t in terms?.value ?? const <AcademicItem>[])
              PickerOption(t.id, t.name),
          ],
          value: draft.termId,
          errorText: err(draft.termId),
          onChanged: (v) => onChanged(draft.copyWith(termId: Nullable(v))),
        ),
        const SizedBox(height: AppSpacing.md),
        PickerField<String>(
          label: l.examType,
          icon: Icons.fact_check_outlined,
          loading: types.isLoading,
          options: [
            for (final t in types.value ?? const <AcademicItem>[])
              PickerOption(t.id, t.name),
          ],
          value: draft.examTypeId,
          errorText: err(draft.examTypeId),
          onChanged: (v) => onChanged(draft.copyWith(examTypeId: Nullable(v))),
        ),
      ],
    );
  }
}

/// Localized names of missing mandatory fields.
String describeMissing(BuildContext context, Set<DraftField> fields) {
  final l = context.l10n;
  return fields
      .map(
        (f) => switch (f) {
          DraftField.title => l.title,
          DraftField.subject => l.subject,
          DraftField.doctor => l.doctor,
          DraftField.category => l.category,
          DraftField.examYear => l.examYear,
          DraftField.term => l.term,
          DraftField.examType => l.examType,
          DraftField.file => l.file,
        },
      )
      .join('، ');
}
