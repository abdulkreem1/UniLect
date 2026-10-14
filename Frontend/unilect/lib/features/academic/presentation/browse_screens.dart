import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/state_views.dart';
import '../application/academic_providers.dart';
import '../domain/academic_models.dart';
import 'widgets/browse_list.dart';

/// FR-025: faculties of the selected university.
class FacultiesScreen extends ConsumerWidget {
  const FacultiesScreen({
    super.key,
    required this.universityId,
    required this.title,
  });

  final String universityId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return BrowseList<Faculty>(
      title: title,
      subtitle: l.faculties,
      value: ref.watch(facultiesProvider(universityId)),
      onRefresh: () => ref.refresh(facultiesProvider(universityId).future),
      empty: EmptyView(
        icon: Icons.domain_outlined,
        title: l.emptyFaculties,
        message: l.emptyGenericHint,
      ),
      itemBuilder: (context, f) => NavCard(
        icon: Icons.domain_rounded,
        title: f.name,
        onTap: () => context.push(Routes.years(f.id, f.name)),
      ),
    );
  }
}

/// FR-026: academic years of the selected faculty.
class YearsScreen extends ConsumerWidget {
  const YearsScreen({super.key, required this.facultyId, required this.title});

  final String facultyId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return BrowseList<AcademicYear>(
      title: title,
      subtitle: l.years,
      value: ref.watch(yearsProvider(facultyId)),
      onRefresh: () => ref.refresh(yearsProvider(facultyId).future),
      empty: EmptyView(
        icon: Icons.layers_outlined,
        title: l.emptyYears,
        message: l.emptyGenericHint,
      ),
      itemBuilder: (context, y) => NavCard(
        leading: _LevelBadge(level: y.level),
        title: y.name,
        onTap: () => context.push(Routes.subjects(facultyId, y.id, y.name)),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// FR-027 + FR-020: subjects of the selected year, filterable by
/// specialization.
class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({
    super.key,
    required this.facultyId,
    required this.yearId,
    required this.title,
  });

  final String facultyId;
  final String yearId;
  final String title;

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  String? _specializationId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = (yearId: widget.yearId, specializationId: _specializationId);
    final specs = ref.watch(specializationsProvider(widget.facultyId)).value;
    return BrowseList<Subject>(
      title: widget.title,
      subtitle: l.subjects,
      value: ref.watch(subjectsProvider(args)),
      onRefresh: () => ref.refresh(subjectsProvider(args).future),
      header: (specs == null || specs.isEmpty)
          ? null
          : SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                children: [
                  ChoiceChip(
                    label: Text(l.allSpecializations),
                    selected: _specializationId == null,
                    onSelected: (_) => setState(() => _specializationId = null),
                  ),
                  for (final s in specs) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _specializationId == s.id,
                      onSelected: (_) =>
                          setState(() => _specializationId = s.id),
                    ),
                  ],
                ],
              ),
            ),
      empty: EmptyView(
        icon: Icons.menu_book_outlined,
        title: l.emptySubjects,
        message: l.emptyGenericHint,
      ),
      itemBuilder: (context, s) => NavCard(
        icon: Icons.menu_book_rounded,
        title: s.name,
        subtitle: s.code,
        onTap: () => context.push(Routes.subject(s.id, s.name)),
      ),
    );
  }
}
