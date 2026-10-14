import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/state_views.dart';
import '../../academic/application/academic_providers.dart';
import '../../academic/domain/academic_models.dart';
import '../application/admin_providers.dart';

/// FR-059 / FR-060: content providers and the academic scope each may
/// publish in. Library accounts are attached to one library.
class LibrariesScreen extends ConsumerWidget {
  const LibrariesScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Library? lib,
  ]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _LibraryEditor(library: lib),
    );
    if (saved == true) {
      ref.invalidate(librariesProvider);
      if (context.mounted) {
        AppFeedback.success(context, context.l10n.librarySaved);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final libraries = ref.watch(librariesProvider);
    final colors = Theme.of(context).extension<StatusColors>()!;
    return Scaffold(
      appBar: AppBar(title: Text(l.libraries)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.newLibrary),
      ),
      body: AsyncValueView<List<Library>>(
        value: libraries,
        onRetry: () => ref.invalidate(librariesProvider),
        isEmpty: (list) => list.isEmpty,
        empty: EmptyView(
          icon: Icons.local_library_outlined,
          title: l.emptyLibraries,
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(librariesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final lib = list[i];
              return NavCard(
                leading: const IconBadge(
                  icon: Icons.local_library_rounded,
                  color: AppColors.sky500,
                ),
                title: lib.name,
                subtitle: [
                  ?lib.contactEmail,
                  l.staffCount(lib.staffCount),
                ].join(' · '),
                badge: Pill(
                  label: lib.isActive ? l.statusActive : l.statusDisabled,
                  color: lib.isActive ? colors.success : colors.danger,
                ),
                onTap: () => _edit(context, ref, lib),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LibraryEditor extends ConsumerStatefulWidget {
  const _LibraryEditor({this.library});
  final Library? library;

  @override
  ConsumerState<_LibraryEditor> createState() => _LibraryEditorState();
}

class _LibraryEditorState extends ConsumerState<_LibraryEditor> {
  final _form = GlobalKey<FormState>();
  late final Library? _lib = widget.library;
  late final _name = TextEditingController(text: _lib?.name ?? '');
  late final _email = TextEditingController(text: _lib?.contactEmail ?? '');
  late final _phone = TextEditingController(text: _lib?.contactPhone ?? '');
  late bool _active = _lib?.isActive ?? true;
  late Set<String> _universities = {...?_lib?.universityIds};
  late Set<String> _faculties = {...?_lib?.facultyIds};
  bool _scopeError = false;
  bool _saving = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    final hasScope =
        _universities.isNotEmpty ||
        _faculties.isNotEmpty ||
        (_lib?.subjectIds.isNotEmpty ?? false);
    setState(() => _scopeError = !hasScope);
    if (!valid || !hasScope) return;
    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      await ref
          .read(academicRepositoryProvider)
          .saveLibrary(
            id: _lib?.id,
            name: _name.text,
            isActive: _active,
            contactEmail: _email.text,
            contactPhone: _phone.text,
            universityIds: _universities,
            facultyIds: _faculties,
          );
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
                _lib == null ? l.newLibrary : l.editLibrary,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _name,
                validator: Validators.minLength(context, 3),
                decoration: InputDecoration(
                  labelText: l.name,
                  errorText: _errors['name'],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? null
                    : Validators.email(context)(v),
                decoration: InputDecoration(
                  labelText: '${l.contactEmail} (${l.optional})',
                  errorText: _errors['contact_email'],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: '${l.contactPhone} (${l.optional})',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.statusActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SectionHeader(title: l.scopeLabel),
              ScopePicker(
                universities: _universities,
                faculties: _faculties,
                onChanged: (u, f) => setState(() {
                  _universities = u;
                  _faculties = f;
                  _scopeError = false;
                }),
              ),
              if (_scopeError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    l.scopeRequired,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              GradientButton(label: l.save, loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whole universities and/or single faculties a library may publish in.
class ScopePicker extends ConsumerWidget {
  const ScopePicker({
    super.key,
    required this.universities,
    required this.faculties,
    required this.onChanged,
  });

  final Set<String> universities;
  final Set<String> faculties;
  final void Function(Set<String> universities, Set<String> faculties)
  onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unis = ref.watch(universitiesProvider);
    return switch (unis) {
      AsyncData(:final value) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final u in value)
              ExpansionTile(
                key: PageStorageKey(u.id),
                title: Text(u.name),
                leading: Checkbox(
                  value: universities.contains(u.id),
                  semanticLabel: '${l.scopeUniversities}: ${u.name}',
                  onChanged: (on) => onChanged(
                    on == true
                        ? {...universities, u.id}
                        : ({...universities}..remove(u.id)),
                    faculties,
                  ),
                ),
                subtitle: Text(
                  l.scopeUniversities,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  _FacultyChecks(
                    universityId: u.id,
                    disabled: universities.contains(u.id),
                    selected: faculties,
                    onChanged: (f) => onChanged(universities, f),
                  ),
                ],
              ),
          ],
        ),
      ),
      AsyncError(:final error) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(universitiesProvider),
      ),
      _ => const Skeleton(height: 160, radius: 20),
    };
  }
}

class _FacultyChecks extends ConsumerWidget {
  const _FacultyChecks({
    required this.universityId,
    required this.disabled,
    required this.selected,
    required this.onChanged,
  });

  final String universityId;
  final bool disabled;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facs = ref.watch(facultiesProvider(universityId)).value ?? const [];
    return Column(
      children: [
        for (final f in facs)
          CheckboxListTile(
            dense: true,
            value: disabled || selected.contains(f.id),
            title: Text(f.name),
            subtitle: Text(context.l10n.scopeFaculties),
            onChanged: disabled
                ? null
                : (on) => onChanged(
                    on == true
                        ? {...selected, f.id}
                        : ({...selected}..remove(f.id)),
                  ),
          ),
      ],
    );
  }
}
