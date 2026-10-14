import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/form_fields.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(sessionControllerProvider.notifier)
          .login(_email.text, _password.text);
      if (!mounted) return;
      if (outcome is DeviceBlocked) {
        unawaited(context.push(Routes.deviceBlocked, extra: outcome.mismatch));
      }
      // LoggedIn: the router guard redirects to the role's home.
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = context.failureMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _reasonMessage(String? code) {
    final l = context.l10n;
    return switch (code) {
      null => null,
      ErrorCodes.deviceMismatch => l.sessionEndedDevice,
      ErrorCodes.accountDisabled => l.sessionEndedDisabled,
      _ => l.sessionEndedRevoked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionControllerProvider);
    final reason = session is SignedOut
        ? _reasonMessage(session.reasonCode)
        : null;

    return AuthScaffold(
      title: l.loginWelcome,
      subtitle: l.loginSubtitle,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null) ...[
                InfoBanner(
                  message: reason,
                  icon: Icons.shield_outlined,
                  color: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textDirection: TextDirection.ltr,
                validator: Validators.email(context),
                decoration: InputDecoration(
                  labelText: l.email,
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                label: l.password,
                validator: Validators.required(context),
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: Text(l.forgotPassword),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: InfoBanner(
                          message: _error!,
                          icon: Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GradientButton(
                label: l.signIn,
                loading: _loading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l.noAccountHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
