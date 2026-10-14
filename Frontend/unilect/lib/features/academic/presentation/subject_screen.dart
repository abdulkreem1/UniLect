import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/filter_chip_picker.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../content/application/student_content_providers.dart';
import '../../content/domain/content.dart';
import '../../content/presentation/widgets/content_widgets.dart';
import '../application/academic_providers.dart';
import '../domain/academic_models.dart';

/// Subject hub: doctors (FR-028) and past exams with filters (FR-030, FR-050).
class SubjectScreen extends ConsumerWidget {
  const SubjectScreen({
    super.key,
    required this.subjectId,
    required this.title,
  });

  final String subjectId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 170,
              foregroundColor: Colors.white,
              backgroundColor: AppColors.navy900,
              actions: [_FollowButton(subjectId: subjectId)],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  bottom: 62,
                  end: 56,
                ),
                title: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                background: const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.heroGradient),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: 24, bottom: 30),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 84,
                        color: Color(0x2238C6F4),
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                indicatorColor: AppColors.cyan400,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: l.doctors),
                  Tab(text: l.exams),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _DoctorsTab(subjectId: subjectId, subjectTitle: title),
              _ExamsTab(subjectId: subjectId),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final followed = ref.watch(followedSubjectsProvider).value;
    final isFollowing = followed?.contains(subjectId) ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Tooltip(
        message: l.followHint,
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: followed == null
              ? null
              : () async {
                  try {
                    final now = await ref
                        .read(followedSubjectsProvider.notifier)
                        .toggle(subjectId);
                    if (context.mounted) {
                      AppFeedback.success(
                        context,
                        now ? l.followed : l.unfollowed,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) AppFeedback.error(context, e);
                  }
                },
          icon: Icon(
            isFollowing
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          ),
          label: Text(isFollowing ? l.following : l.follow),
        ),
      ),
    );
  }
}

class _DoctorsTab extends ConsumerWidget {
  const _DoctorsTab({required this.subjectId, required this.subjectTitle});

  final String subjectId;
  final String subjectTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final doctors = ref.watch(doctorsProvider(subjectId));
    Future<void> refresh() => ref.refresh(doctorsProvider(subjectId).future);
    return AsyncValueView<List<Doctor>>(
      value: doctors,
      onRetry: refresh,
      isEmpty: (d) => d.isEmpty,
      empty: EmptyView(
        icon: Icons.person_search_outlined,
        title: l.emptyDoctors,
        message: l.emptyGenericHint,
      ),
      data: (list) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView.separated(
          padding: AppSpacing.page,
          itemCount: list.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text(
                l.chooseDoctor,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            final d = list[i - 1];
            return FadeInItem(
              index: i,
              child: NavCard(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: d.name,
                onTap: () => context.push(
                  Routes.doctorLectures(
                    subjectId,
                    d.id,
                    '${d.name} · $subjectTitle',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ExamsTab extends ConsumerStatefulWidget {
  const _ExamsTab({required this.subjectId});
  final String subjectId;

  @override
  ConsumerState<_ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends ConsumerState<_ExamsTab> {
  ExamFilter _filter = const ExamFilter();

  void _set(ExamFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = (subjectId: widget.subjectId, filter: _filter);
    final exams = ref.watch(examsProvider(args));
    // Year options come from the unfiltered list (FR-047: browse by year).
    final all = ref
        .watch(
          examsProvider((
            subjectId: widget.subjectId,
            filter: const ExamFilter(),
          )),
        )
        .value;
    final years = {
      for (final e in all ?? const <Content>[]) ?e.examYear,
    }.toList()..sort((a, b) => b.compareTo(a));
    // Semesters are defined per faculty: take the course's own faculty.
    final facultyId = ref
        .watch(subjectProvider(widget.subjectId))
        .value
        ?.facultyId;
    final terms = facultyId == null
        ? const <Term>[]
        : ref.watch(termsProvider(facultyId)).value ?? const <Term>[];
    final types = ref.watch(examTypesProvider).value ?? const [];
    final doctors =
        ref.watch(doctorsProvider(widget.subjectId)).value ?? const [];
    Future<void> refresh() => ref.refresh(examsProvider(args).future);

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              FilterChipPicker<int>(
                label: l.examYear,
                value: _filter.examYear,
                options: [for (final y in years) PickerOption(y, '$y')],
                onChanged: (v) => _set(_filter.copyWith(examYear: Nullable(v))),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChipPicker<String>(
                label: l.examType,
                value: _filter.examTypeId,
                options: [for (final t in types) PickerOption(t.id, t.name)],
                onChanged: (v) =>
                    _set(_filter.copyWith(examTypeId: Nullable(v))),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChipPicker<String>(
                label: l.term,
                value: _filter.termId,
                options: [for (final t in terms) PickerOption(t.id, t.name)],
                onChanged: (v) => _set(_filter.copyWith(termId: Nullable(v))),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilterChipPicker<String>(
                label: l.doctor,
                value: _filter.doctorId,
                options: [for (final d in doctors) PickerOption(d.id, d.name)],
                onChanged: (v) => _set(_filter.copyWith(doctorId: Nullable(v))),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<Content>>(
            value: exams,
            onRetry: refresh,
            isEmpty: (e) => e.isEmpty,
            empty: EmptyView(
              icon: Icons.quiz_outlined,
              title: l.emptyExams,
              message: _filter.activeCount > 0
                  ? l.noResultsHint
                  : l.emptyGenericHint,
              action: _filter.activeCount > 0
                  ? TextButton(
                      onPressed: () => _set(const ExamFilter()),
                      child: Text(l.clearFilters),
                    )
                  : null,
            ),
            data: (list) => RefreshIndicator(
              onRefresh: refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => FadeInItem(
                  index: i,
                  child: ContentTile(
                    content: list[i],
                    onTap: () => context.push(Routes.content(list[i].id)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// FR-029: published lectures of a doctor within the subject, in order.
class DoctorLecturesScreen extends ConsumerWidget {
  const DoctorLecturesScreen({
    super.key,
    required this.subjectId,
    required this.doctorId,
    required this.title,
  });

  final String subjectId;
  final String doctorId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final args = (subjectId: subjectId, doctorId: doctorId);
    final lectures = ref.watch(lecturesProvider(args));
    Future<void> refresh() => ref.refresh(lecturesProvider(args).future);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.lectures),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: AsyncValueView<List<Content>>(
        value: lectures,
        onRetry: refresh,
        isEmpty: (c) => c.isEmpty,
        empty: EmptyView(
          icon: Icons.video_library_outlined,
          title: l.emptyLectures,
          message: l.emptyGenericHint,
        ),
        data: (list) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Pill(
                  label: l.lecturesCount(list.length),
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.layers_rounded,
                );
              }
              final c = list[i - 1];
              return FadeInItem(
                index: i,
                child: ContentTile(
                  content: c,
                  onTap: () => context.push(Routes.content(c.id)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
