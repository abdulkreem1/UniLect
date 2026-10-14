import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../academic/application/academic_providers.dart';
import '../../academic/domain/academic_models.dart';
import '../../auth/domain/user.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';

/// FR-001 / FR-005 / FR-006 / FR-059: create or edit an account, assign its
/// role, the student's university or the library account's library.
class UserFormScreen extends ConsumerWidget {
  const UserFormScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = userId;
    if (id == null) return const _UserForm();
    final user = ref.watch(adminUserProvider(id));
    return user.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonList(count: 5)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(adminUserProvider(id)),
        ),
      ),
      data: (u) => _UserForm(existing: u),
    );
  }
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({this.existing});
  final AppUser? existing;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _form = GlobalKey<FormState>();
  late AppUser? _user = widget.existing;
  late UserRole _role = _user?.role ?? UserRole.student;
  late final _name = TextEditingController(text: _user?.fullName ?? '');
  late final _email = TextEditingController(text: _user?.email ?? '');
  late final _number = TextEditingController(text: _user?.studentNumber ?? '');
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  final _password = TextEditingController();
  late String? _universityId = _user?.universityId;
  late String? _libraryId = _user?.libraryId;
  Map<String, String> _serverErrors = const {};
  bool _saving = false;

  bool get _isEdit => _user != null;

  @override
  void dispose() {
    for (final c in [_name, _email, _number, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Server validation message (already localized) for an API field.
  String? _fieldError(String key) => _serverErrors[key];

  void _refreshLists() => ref
    ..invalidate(usersListProvider)
    ..invalidate(adminDashboardProvider);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _serverErrors = const {};
    });
    final form = UserForm(
      role: _role,
      fullName: _name.text,
      email: _email.text,
      studentNumber: _number.text,
      universityId: _universityId,
      libraryId: _libraryId,
      phone: _phone.text,
      initialPassword: _password.text,
    );
    final repo = ref.read(adminRepositoryProvider);
    try {
      final saved = _isEdit
          ? await repo.updateUser(_user!.id, form)
          : await repo.createUser(form);
      _refreshLists();
      ref.invalidate(adminUserProvider(saved.id));
      if (!mounted) return;
      AppFeedback.success(
        context,
        _isEdit ? context.l10n.userUpdated : context.l10n.userCreated,
      );
      context.pop();
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() => _serverErrors = f.fields);
      _form.currentState!.validate();
      AppFeedback.error(context, f);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleEnabled() async {
    final l = context.l10n;
    final user = _user!;
    if (user.isActive) {
      final ok = await AppFeedback.confirm(
        context,
        title: l.disable,
        message: l.disableConfirm(user.fullName),
        confirmLabel: l.disable,
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      final updated = await ref
          .read(adminRepositoryProvider)
          .setUserEnabled(user.id, enabled: !user.isActive);
      _refreshLists();
      if (!mounted) return;
      setState(() => _user = updated);
      AppFeedback.success(context, l.userUpdated);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  Future<void> _resetDevice() async {
    final l = context.l10n;
    final user = _user!;
    final ok = await AppFeedback.confirm(
      context,
      title: l.resetDevice,
      message: l.resetDeviceConfirm(user.fullName),
      confirmLabel: l.resetDevice,
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(adminRepositoryProvider);
    try {
      await repo.resetDevice(user.id);
      final updated = await repo.user(user.id);
      ref.invalidate(deviceRequestsProvider);
      if (!mounted) return;
      setState(() => _user = updated);
      AppFeedback.success(context, l.deviceResetDone);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  Future<void> _setPassword() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SetPasswordSheet(userId: _user!.id),
    );
    if ((done ?? false) && mounted) {
      AppFeedback.success(context, context.l10n.passwordSet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = _user;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final universities = _role == UserRole.student
        ? ref.watch(universitiesProvider)
        : null;
    final libraries = _role == UserRole.library
        ? ref.watch(librariesProvider)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? l.editUser : l.newUser)),
      body: Form(
        key: _form,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            if (user != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Pill(
                            label: l.roleLabel(user.role),
                            color: AppColors.blue600,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Pill(
                            label: user.isActive
                                ? l.statusActive
                                : l.statusDisabled,
                            color: user.isActive
                                ? colors.success
                                : colors.danger,
                          ),
                          const Spacer(),
                          Text(
                            l.createdOn(context.formatDate(user.createdAt)),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      if (user.role == UserRole.student) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            const Icon(Icons.smartphone_rounded, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${l.boundDevice}: ${user.boundDevice?.label ?? l.noBoundDevice}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (!_isEdit) ...[
              Text(l.role, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<UserRole>(
                segments: [
                  for (final r in UserRole.values)
                    ButtonSegment(value: r, label: Text(l.roleLabel(r))),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.minLength(context, 3)(v) ??
                  _fieldError('full_name'),
              decoration: InputDecoration(
                labelText: l.fullName,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.email(context)(v) ?? _fieldError('email'),
              decoration: InputDecoration(
                labelText: l.email,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
            if (_role == UserRole.student) ...[
              const SizedBox(height: AppSpacing.md),
              PickerField<String>(
                label: l.university,
                icon: Icons.account_balance_outlined,
                loading: universities?.isLoading ?? false,
                options: [
                  for (final u in universities?.value ?? const <University>[])
                    PickerOption(u.id, u.name),
                ],
                value: _universityId,
                errorText: _fieldError('university'),
                validator: (v) => v == null ? l.fieldRequired : null,
                onChanged: (v) => setState(() => _universityId = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _number,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.required(context)(v) ??
                    _fieldError('student_number'),
                decoration: InputDecoration(
                  labelText: l.studentNumber,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
            ],
            if (_role == UserRole.library) ...[
              const SizedBox(height: AppSpacing.md),
              PickerField<String>(
                label: l.libraryLabel,
                icon: Icons.local_library_outlined,
                loading: libraries?.isLoading ?? false,
                options: [
                  for (final lib in libraries?.value ?? const <Library>[])
                    PickerOption(lib.id, lib.name),
                ],
                value: _libraryId,
                errorText: _fieldError('library'),
                validator: (v) => v == null ? l.libraryRequired : null,
                onChanged: (v) => setState(() => _libraryId = v),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              validator: (_) => _fieldError('phone'),
              decoration: InputDecoration(
                labelText: '${l.phone} (${l.optional})',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: l.initialPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    Validators.newPassword(context)(v) ??
                    _fieldError('password'),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
                child: Text(
                  l.initialPasswordHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            GradientButton(label: l.save, loading: _saving, onPressed: _save),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.md),
              LoadingButton(
                label: l.setPassword,
                icon: Icons.password_rounded,
                outlined: true,
                onPressed: _setPassword,
              ),
              if (user.boundDevice != null) ...[
                const SizedBox(height: AppSpacing.md),
                LoadingButton(
                  label: l.resetDevice,
                  icon: Icons.phonelink_erase_rounded,
                  outlined: true,
                  destructive: true,
                  onPressed: _resetDevice,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              LoadingButton(
                label: user.isActive ? l.disable : l.enable,
                icon: user.isActive
                    ? Icons.block_rounded
                    : Icons.check_circle_outline_rounded,
                outlined: true,
                destructive: user.isActive,
                onPressed: _toggleEnabled,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _SetPasswordSheet extends ConsumerStatefulWidget {
  const _SetPasswordSheet({required this.userId});
  final String userId;

  @override
  ConsumerState<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends ConsumerState<_SetPasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setUserPassword(widget.userId, _password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.setPassword, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(l.setPasswordHint),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _password,
              label: l.newPassword,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            LoadingButton(label: l.save, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
