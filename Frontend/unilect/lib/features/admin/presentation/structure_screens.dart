import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../academic/domain/academic_models.dart';
import '../application/admin_providers.dart';

extension StructureKindL10n on StructureKind {
  String label(AppLocalizations l) => switch (this) {
    StructureKind.universities => l.universities,
    StructureKind.faculties => l.faculties,
    StructureKind.years => l.years,
    StructureKind.terms => l.terms,
    StructureKind.specializations => l.specializations,
    StructureKind.subjects => l.subjects,
    StructureKind.doctors => l.doctors,
    StructureKind.lectureCategories => l.lectureCategories,
    StructureKind.examTypes => l.examTypes,
  };

  IconData get icon => switch (this) {
    StructureKind.universities => Icons.account_balance_rounded,
    StructureKind.faculties => Icons.domain_rounded,
    StructureKind.years => Icons.layers_rounded,
    StructureKind.terms => Icons.date_range_rounded,
    StructureKind.specializations => Icons.alt_route_rounded,
    StructureKind.subjects => Icons.menu_book_rounded,
    StructureKind.doctors => Icons.person_rounded,
    StructureKind.lectureCategories => Icons.category_rounded,
    StructureKind.examTypes => Icons.fact_check_rounded,
  };
}

class StructureHubScreen extends StatelessWidget {
  const StructureHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.structureTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text(
            l.structureSubtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final (i, kind) in StructureKind.values.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            NavCard(
              icon: kind.icon,
              title: kind.label(l),
              onTap: () => context.push(Routes.adminStructureKind(kind)),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          NavCard(
            leading: const IconBadge(
              icon: Icons.local_library_rounded,
              color: AppColors.sky500,
            ),
            title: l.libraries,
            subtitle: l.librariesSubtitle,
            onTap: () => context.push(Routes.adminLibraries),
          ),
        ],
      ),
    );
  }
}

/// Generic management screen for one structure kind with parent scoping,
/// activation toggle, drag-to-reorder (FR-023) and add/edit.
class StructureKindScreen extends ConsumerStatefulWidget {
  const StructureKindScreen({super.key, required this.kind});
  final StructureKind kind;

  @override
  ConsumerState<StructureKindScreen> createState() =>
      _StructureKindScreenState();
}

class _StructureKindScreenState extends ConsumerState<StructureKindScreen> {
  String? _universityId;
  String? _facultyId;
  List<AcademicItem>? _ordered;

  StructureKind get kind => widget.kind;

  /// Parent id to scope the list, or null when the kind has no parent.
  String? get _parentId => switch (kind.parent) {
    StructureKind.universities => _universityId,
    StructureKind.faculties => _facultyId,
    _ => null,
  };

  bool get _needsParent => kind.parent != null && _parentId == null;

  ({StructureKind kind, String? parentId}) get _args =>
      (kind: kind, parentId: _parentId);

  Future<void> _edit([AcademicItem? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemEditor(kind: kind, parentId: _parentId, item: item),
    );
    if (saved == true) {
      setState(() => _ordered = null);
      ref.invalidate(adminStructureProvider);
      if (mounted) AppFeedback.success(context, context.l10n.itemSaved);
    }
  }

  Future<void> _toggle(AcademicItem item, bool active) async {
    try {
      await ref.read(academicRepositoryProvider).adminUpdate(kind, item.id, {
        'is_active': active,
      });
      setState(() => _ordered = null);
      ref.invalidate(adminStructureProvider);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  Future<void> _reorder(List<AcademicItem> items, int from, int to) async {
    final list = [...items];
    final moved = list.removeAt(from);
    list.insert(to, moved);
    setState(() => _ordered = list);
    try {
      await ref.read(academicRepositoryProvider).adminReorder(kind, [
        for (final i in list) i.id,
      ]);
      if (mounted) AppFeedback.success(context, context.l10n.orderSaved);
    } catch (e) {
      setState(() => _ordered = null);
      if (mounted) AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _needsParent
        ? null
        : ref.watch(adminStructureProvider(_args));
    return Scaffold(
      appBar: AppBar(title: Text(kind.label(l))),
      floatingActionButton: _needsParent
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.addItem),
            ),
      body: Column(
        children: [
          if (kind.parent != null)
            ParentPickers(
              needsFaculty: kind.parent == StructureKind.faculties,
              universityId: _universityId,
              facultyId: _facultyId,
              onChanged: (u, f) => setState(() {
                _universityId = u;
                _facultyId = f;
                _ordered = null;
              }),
            ),
          Expanded(
            child: items == null
                ? EmptyView(
                    icon: Icons.filter_alt_outlined,
                    title: l.chooseParentFirst(
                      (kind.parent == StructureKind.faculties
                          ? l.faculty
                          : l.university),
                    ),
                  )
                : AsyncValueView<List<AcademicItem>>(
                    value: items,
                    onRetry: () =>
                        ref.invalidate(adminStructureProvider(_args)),
                    isEmpty: (i) => i.isEmpty,
                    empty: EmptyView(icon: kind.icon, title: l.emptyItems),
                    data: (fetched) {
                      final list = _ordered ?? fetched;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l.reorderHint,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                              itemCount: list.length,
                              onReorderItem: (a, b) => _reorder(list, a, b),
                              itemBuilder: (context, i) {
                                final item = list[i];
                                return Padding(
                                  key: ValueKey(item.id),
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md,
                                  ),
                                  child: Card(
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsetsDirectional.only(
                                            start: 16,
                                            end: 4,
                                          ),
                                      leading: CircleAvatar(
                                        child: Text('${i + 1}'),
                                      ),
                                      title: Text(item.name),
                                      subtitle: Text(_subtitle(l, item)),
                                      onTap: () => _edit(item),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: item.isActive,
                                            onChanged: (v) => _toggle(item, v),
                                          ),
                                          ReorderableDragStartListener(
                                            index: i,
                                            child: const Padding(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                Icons.drag_handle_rounded,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l, AcademicItem item) => [
    item.isActive ? l.active : l.inactive,
    if (item is AcademicYear) '${l.level} ${item.level}',
    if (item is Term) '${l.number} ${item.number}',
    if (item is Subject && item.code != null) item.code!,
    if (item is Doctor) '${l.linkedSubjects}: ${item.subjectIds.length}',
  ].join(' · ');
}

/// University (and optionally faculty) pickers scoping an admin list.
class ParentPickers extends ConsumerWidget {
  const ParentPickers({
    super.key,
    required this.needsFaculty,
    required this.universityId,
    required this.facultyId,
    required this.onChanged,
  });

  final bool needsFaculty;
  final String? universityId;
  final String? facultyId;
  final void Function(String? universityId, String? facultyId) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unis = ref.watch(
      adminStructureProvider((
        kind: StructureKind.universities,
        parentId: null,
      )),
    );
    final facs = universityId == null || !needsFaculty
        ? null
        : ref.watch(
            adminStructureProvider((
              kind: StructureKind.faculties,
              parentId: universityId,
            )),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          PickerField<String>(
            label: l.university,
            icon: Icons.account_balance_outlined,
            loading: unis.isLoading,
            options: [
              for (final u in unis.value ?? const <AcademicItem>[])
                PickerOption(u.id, u.name),
            ],
            value: universityId,
            onChanged: (v) => onChanged(v, null),
          ),
          if (needsFaculty) ...[
            const SizedBox(height: AppSpacing.md),
            PickerField<String>(
              label: l.faculty,
              icon: Icons.domain_outlined,
              enabled: facs != null,
              loading: facs?.isLoading ?? false,
              options: [
                for (final f in facs?.value ?? const <AcademicItem>[])
                  PickerOption(f.id, f.name),
              ],
              value: facultyId,
              onChanged: (v) => onChanged(universityId, v),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemEditor extends ConsumerStatefulWidget {
  const _ItemEditor({required this.kind, required this.parentId, this.item});

  final StructureKind kind;

  /// University (for faculties) or faculty (for faculty-level kinds).
  final String? parentId;
  final AcademicItem? item;

  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final AcademicItem? _item = widget.item;
  late final _name = TextEditingController(
    text: _item is Doctor ? _item.fullName : _item?.name ?? '',
  );
  late final _title = TextEditingController(
    text: _item is Doctor ? _item.title : 'د.',
  );
  late final _code = TextEditingController(
    text: _item is Subject ? _item.code ?? '' : '',
  );
  late final _number = TextEditingController(
    text: switch (_item) {
      final AcademicYear y => '${y.level}',
      final Term t => '${t.number}',
      _ => '',
    },
  );
  late bool _active = _item?.isActive ?? true;
  late String? _yearId = _item is Subject ? _item.yearId : null;
  late String? _termId = _item is Subject ? _item.termId : null;
  late String? _doctorUniversityId = _item is Doctor
      ? _item.universityId
      : null;
  late final Set<String> _specs = {
    if (_item is Subject) ..._item.specializationIds,
  };
  late final Set<String> _subjects = {if (_item is Doctor) ..._item.subjectIds};
  bool _saving = false;
  Map<String, String> _errors = const {};

  StructureKind get kind => widget.kind;
  bool get _isNew => _item == null;

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _code.dispose();
    _number.dispose();
    super.dispose();
  }

  /// Body in the API's field names for this resource.
  Json _body() {
    final name = _name.text.trim();
    final parent = intId(widget.parentId);
    return switch (kind) {
      StructureKind.doctors => {
        'full_name': name,
        'title': _title.text.trim(),
        'university': intId(_doctorUniversityId),
        'is_active': _active,
      },
      StructureKind.universities ||
      StructureKind.lectureCategories ||
      StructureKind.examTypes => {'name': name, 'is_active': _active},
      StructureKind.faculties => {
        'name': name,
        'is_active': _active,
        if (_isNew) 'university': parent,
      },
      StructureKind.specializations => {
        'name': name,
        'is_active': _active,
        if (_isNew) 'faculty': parent,
      },
      StructureKind.years || StructureKind.terms => {
        'name': name,
        'number': int.tryParse(_number.text) ?? 1,
        'is_active': _active,
        if (_isNew) 'faculty': parent,
      },
      StructureKind.subjects => {
        'name': name,
        'code': _code.text.trim(),
        'level': intId(_yearId),
        'semester': intId(_termId),
        'specializations': [for (final s in _specs) intId(s)],
        'is_active': _active,
      },
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errors = const {};
    });
    final repo = ref.read(academicRepositoryProvider);
    try {
      final item = _item;
      final saved = item == null
          ? await repo.adminCreate(kind, _body())
          : await repo.adminUpdate(kind, item.id, _body());
      if (kind == StructureKind.doctors) {
        await repo.setDoctorSubjects(saved.id, _subjects);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e is ApiFailure ? e.fields : const {};
      });
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final facultyId = switch (_item) {
      final Subject s => s.facultyId,
      _ => widget.parentId,
    };
    AsyncValue<List<AcademicItem>>? listOf(StructureKind k) => facultyId == null
        ? null
        : ref.watch(adminStructureProvider((kind: k, parentId: facultyId)));
    final isSubject = kind == StructureKind.subjects;
    final years = isSubject ? listOf(StructureKind.years) : null;
    final terms = isSubject ? listOf(StructureKind.terms) : null;
    final specs = isSubject ? listOf(StructureKind.specializations) : null;
    final universities = kind == StructureKind.doctors
        ? ref.watch(
            adminStructureProvider((
              kind: StructureKind.universities,
              parentId: null,
            )),
          )
        : null;
    final uniSubjects =
        kind == StructureKind.doctors && _doctorUniversityId != null
        ? ref.watch(adminUniversitySubjectsProvider(_doctorUniversityId!))
        : null;
    List<PickerOption<String>> options(AsyncValue<List<AcademicItem>>? v) => [
      for (final e in v?.value ?? const <AcademicItem>[])
        PickerOption(e.id, e.name),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_isNew ? l.addItem : l.editItem} · ${kind.label(l)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (kind == StructureKind.doctors) ...[
                TextFormField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: '${l.doctorTitle} (${l.optional})',
                    errorText: _errors['title'],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              TextFormField(
                controller: _name,
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? l.fieldRequired : null,
                decoration: InputDecoration(
                  labelText: kind == StructureKind.doctors
                      ? l.fullName
                      : l.name,
                  errorText: _errors['name'] ?? _errors['full_name'],
                ),
              ),
              if (kind == StructureKind.years ||
                  kind == StructureKind.terms) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      (int.tryParse(v ?? '') ?? 0) < 1 ? l.fieldRequired : null,
                  decoration: InputDecoration(
                    labelText: kind == StructureKind.years ? l.level : l.number,
                    errorText: _errors['number'] ?? _errors['non_field_errors'],
                  ),
                ),
              ],
              if (isSubject) ...[
                const SizedBox(height: AppSpacing.md),
                PickerField<String>(
                  label: l.year,
                  loading: years?.isLoading ?? false,
                  options: options(years),
                  value: _yearId,
                  errorText: _errors['level'],
                  validator: (v) => v == null ? l.fieldRequired : null,
                  onChanged: (v) => setState(() => _yearId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                PickerField<String>(
                  label: '${l.term} (${l.optional})',
                  loading: terms?.isLoading ?? false,
                  allowClear: true,
                  options: options(terms),
                  value: _termId,
                  errorText: _errors['semester'],
                  onChanged: (v) => setState(() => _termId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _code,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: '${l.code} (${l.optional})',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.linkedSpecializations,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in specs?.value ?? const <AcademicItem>[])
                      FilterChip(
                        label: Text(s.name),
                        selected: _specs.contains(s.id),
                        onSelected: (on) => setState(
                          () => on ? _specs.add(s.id) : _specs.remove(s.id),
                        ),
                      ),
                  ],
                ),
              ],
              if (kind == StructureKind.doctors) ...[
                const SizedBox(height: AppSpacing.md),
                PickerField<String>(
                  label: l.university,
                  icon: Icons.account_balance_outlined,
                  loading: universities?.isLoading ?? false,
                  options: options(universities),
                  value: _doctorUniversityId,
                  errorText: _errors['university'],
                  onChanged: (v) => setState(() {
                    _doctorUniversityId = v;
                    _subjects.clear();
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.linkedSubjects,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in uniSubjects?.value ?? const <Subject>[])
                      FilterChip(
                        label: Text([s.name, ?s.code].join(' · ')),
                        selected: _subjects.contains(s.id),
                        onSelected: (on) => setState(
                          () =>
                              on ? _subjects.add(s.id) : _subjects.remove(s.id),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.visibleToStudents),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              LoadingButton(label: l.save, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
