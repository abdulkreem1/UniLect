import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';

/// FR-007 profile (view + editable fields), password change, language and
/// logout (FR-003).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final locale = ref.watch(localeControllerProvider);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.brandGradient,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Pill(
                        label: l.roleLabel(user.role),
                        color: AppColors.cyan400,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            title: l.accountSection,
            action: TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _EditProfileSheet(user: user),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l.edit),
            ),
          ),
          Card(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: l.fullName,
                  value: user.fullName,
                  locked: user.role == UserRole.student,
                ),
                _InfoRow(
                  icon: Icons.alternate_email_rounded,
                  label: l.email,
                  value: user.email,
                  locked: true,
                ),
                if (user.studentNumber != null)
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: l.studentNumber,
                    value: user.studentNumber!,
                    locked: true,
                  ),
                if (user.universityName != null)
                  _InfoRow(
                    icon: Icons.account_balance_outlined,
                    label: l.university,
                    value: user.universityName!,
                    locked: true,
                  ),
                if (user.libraryName != null)
                  _InfoRow(
                    icon: Icons.local_library_outlined,
                    label: l.libraryLabel,
                    value: user.libraryName!,
                    locked: true,
                  ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: l.phone,
                  value: user.phone ?? '—',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              l.protectedFieldsNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SectionHeader(title: l.preferencesSection),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(l.language),
                  trailing: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'ar', label: Text(l.arabic)),
                      ButtonSegment(value: 'en', label: Text(l.english)),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (s) => ref
                        .read(localeControllerProvider.notifier)
                        .set(Locale(s.first)),
                  ),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(l.changePassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const _ChangePasswordSheet(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          LoadingButton(
            label: l.logout,
            icon: Icons.logout_rounded,
            outlined: true,
            destructive: true,
            onPressed: () async {
              final ok = await AppFeedback.confirm(
                context,
                title: l.logout,
                message: l.logoutConfirm,
                confirmLabel: l.logout,
                destructive: true,
              );
              if (ok) {
                await ref.read(sessionControllerProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
      trailing: locked
          ? Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .update(
            role: widget.user.role,
            fullName: _name.text,
            phone: _phone.text,
          );
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      if (!mounted) return;
      AppFeedback.success(context, context.l10n.profileSaved);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _SheetPadding(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.editProfile, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              // Students' names are managed by the administrator (FR-007).
              enabled: widget.user.role != UserRole.student,
              validator: Validators.minLength(context, 3),
              decoration: InputDecoration(
                labelText: l.fullName,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: '${l.phone} (${l.optional})',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            LoadingButton(
              label: l.saveChanges,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      AppFeedback.success(context, context.l10n.passwordChanged);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _SheetPadding(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.changePassword,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            PasswordField(
              controller: _current,
              label: l.currentPassword,
              textInputAction: TextInputAction.next,
              validator: Validators.required(context),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _next,
              label: l.newPassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword(context),
            ),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _confirm,
              label: l.confirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => v != _next.text ? l.passwordsDontMatch : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            LoadingButton(label: l.save, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _SheetPadding extends StatelessWidget {
  const _SheetPadding({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}
