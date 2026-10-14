import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../application/session_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Accounts created or reset by an administrator carry a temporary password.
/// Until it is replaced the API answers `password_change_required` to
/// everything except this change and logout, so the router keeps the user
/// here.
class ChangePasswordRequiredScreen extends ConsumerStatefulWidget {
  const ChangePasswordRequiredScreen({super.key});

  @override
  ConsumerState<ChangePasswordRequiredScreen> createState() =>
      _ChangePasswordRequiredScreenState();
}

class _ChangePasswordRequiredScreenState
    extends ConsumerState<ChangePasswordRequiredScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      AppFeedback.success(context, context.l10n.passwordChanged);
      ref.read(sessionControllerProvider.notifier).passwordChanged();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = context.failureMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthScaffold(
      title: l.mustChangeTitle,
      subtitle: l.mustChangeBody,
      compactHero: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _current,
                label: l.currentPassword,
                textInputAction: TextInputAction.next,
                validator: Validators.required(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _next,
                label: l.newPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.newPassword(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _confirm,
                label: l.confirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _next.text ? l.passwordsDontMatch : null,
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.lg),
                InfoBanner(
                  message: _error!,
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                label: l.changePassword,
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () =>
                          ref.read(sessionControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded),
                label: Text(l.logout),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
