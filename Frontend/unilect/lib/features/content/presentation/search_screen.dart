import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../academic/application/academic_providers.dart';
import '../application/student_content_providers.dart';
import '../domain/content.dart';
import 'widgets/content_widgets.dart';

/// FR-031 / FR-032: keyword search over lectures and past exams the student
/// may see, with academic filters.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref.read(searchControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final controller = ref.read(searchControllerProvider.notifier);
    final current = ref.read(searchControllerProvider).query;
    final result = await showModalBottomSheet<ContentQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: current),
    );
    if (result != null) controller.setQuery(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(searchControllerProvider);
    final filters = state.query.activeFilterCount;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSearch)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    onChanged: ref
                        .read(searchControllerProvider.notifier)
                        .setText,
                    decoration: InputDecoration(
                      hintText: l.searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _text.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l.clearFilters,
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _text.clear();
                                ref
                                    .read(searchControllerProvider.notifier)
                                    .setText('');
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Badge(
                  isLabelVisible: filters > 0,
                  label: Text('$filters'),
                  child: IconButton.filledTonal(
                    tooltip: l.filters,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(54, 54),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (state.results) {
              AsyncData(value: null) => EmptyView(
                icon: Icons.travel_explore_rounded,
                title: l.searchPrompt,
              ),
              AsyncData(:final value?) when value.items.isEmpty => EmptyView(
                icon: Icons.search_off_rounded,
                title: l.noResults,
                message: l.noResultsHint,
              ),
              AsyncData(:final value?) => ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: value.items.length + 2,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text(
                      l.resultsCount(value.total),
                      style: Theme.of(context).textTheme.labelLarge,
                    );
                  }
                  if (i == value.items.length + 1) {
                    return state.loadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : const SizedBox.shrink();
                  }
                  final c = value.items[i - 1];
                  return ContentTile(
                    content: c,
                    showPath: true,
                    onTap: () => context.push(Routes.content(c.id)),
                  );
                },
              ),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: ref.read(searchControllerProvider.notifier).retry,
              ),
              _ => const SkeletonList(),
            },
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final ContentQuery initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ContentType? _type = widget.initial.type;
  late String? _university = widget.initial.universityId;
  late String? _faculty = widget.initial.facultyId;
  late String? _year = widget.initial.yearId;
  late String? _subject = widget.initial.subjectId;
  late String? _doctor = widget.initial.doctorId;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    List<PickerOption<String>> opts<T>(
      AsyncValue<List<T>> v,
      String Function(T) id,
      String Function(T) name,
    ) => [for (final e in v.value ?? <T>[]) PickerOption(id(e), name(e))];

    final unis = ref.watch(universitiesProvider);
    final facs = _university == null
        ? null
        : ref.watch(facultiesProvider(_university!));
    final years = _faculty == null ? null : ref.watch(yearsProvider(_faculty!));
    final subjects = _year == null
        ? null
        : ref.watch(subjectsProvider((yearId: _year!, specializationId: null)));
    final doctors = _subject == null
        ? null
        : ref.watch(doctorsProvider(_subject!));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.filters, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            Text(l.contentType, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ContentType?>(
              segments: [
                ButtonSegment(value: null, label: Text(l.all)),
                ButtonSegment(
                  value: ContentType.lecture,
                  label: Text(l.lectures),
                ),
                ButtonSegment(value: ContentType.exam, label: Text(l.exams)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            PickerField<String>(
              label: l.university,
              icon: Icons.account_balance_outlined,
              allowClear: true,
              loading: unis.isLoading,
              options: opts(unis, (e) => e.id, (e) => e.name),
              value: _university,
              onChanged: (v) => setState(() {
                _university = v;
                _faculty = _year = _subject = _doctor = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField<String>(
              label: l.faculty,
              icon: Icons.domain_outlined,
              allowClear: true,
              enabled: facs != null,
              loading: facs?.isLoading ?? false,
              options: facs == null
                  ? const []
                  : opts(facs, (e) => e.id, (e) => e.name),
              value: _faculty,
              onChanged: (v) => setState(() {
                _faculty = v;
                _year = _subject = _doctor = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField<String>(
              label: l.year,
              icon: Icons.layers_outlined,
              allowClear: true,
              enabled: years != null,
              loading: years?.isLoading ?? false,
              options: years == null
                  ? const []
                  : opts(years, (e) => e.id, (e) => e.name),
              value: _year,
              onChanged: (v) => setState(() {
                _year = v;
                _subject = _doctor = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField<String>(
              label: l.subject,
              icon: Icons.menu_book_outlined,
              allowClear: true,
              enabled: subjects != null,
              loading: subjects?.isLoading ?? false,
              options: subjects == null
                  ? const []
                  : opts(subjects, (e) => e.id, (e) => e.name),
              value: _subject,
              onChanged: (v) => setState(() {
                _subject = v;
                _doctor = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField<String>(
              label: l.doctor,
              icon: Icons.person_outline_rounded,
              allowClear: true,
              enabled: doctors != null,
              loading: doctors?.isLoading ?? false,
              options: doctors == null
                  ? const []
                  : opts(doctors, (e) => e.id, (e) => e.name),
              value: _doctor,
              onChanged: (v) => setState(() => _doctor = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ContentQuery(text: widget.initial.text),
                    ),
                    child: Text(l.clearFilters),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ContentQuery(
                        text: widget.initial.text,
                        type: _type,
                        universityId: _university,
                        facultyId: _faculty,
                        yearId: _year,
                        subjectId: _subject,
                        doctorId: _doctor,
                      ),
                    ),
                    child: Text(l.apply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
