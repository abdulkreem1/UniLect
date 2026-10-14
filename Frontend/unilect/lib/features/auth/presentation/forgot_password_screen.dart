import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_scaffold.dart';

enum _Step { email, link, password }

/// FR-004: the server emails a one-time link (valid for one hour). Opening it
/// on the phone lands directly on the new-password step
/// (`unilect://app/reset-password?uid=…&token=…`); it can also be pasted.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.link});

  /// Present when the app was opened from the emailed link.
  final ResetLink? link;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pasted = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late _Step _step = widget.link == null ? _Step.email : _Step.password;
  late ResetLink? _link = widget.link;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _pasted, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = context.failureMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendLink() => _run(() async {
    await ref.read(authRepositoryProvider).requestPasswordReset(_email.text);
    if (mounted) setState(() => _step = _Step.link);
  });

  Future<void> _usePastedLink() => _run(() async {
    setState(() {
      _link = ResetLink.tryParse(_pasted.text);
      _step = _Step.password;
    });
  });

  Future<void> _reset() => _run(() async {
    await ref
        .read(authRepositoryProvider)
        .confirmPasswordReset(link: _link!, newPassword: _password.text);
    if (!mounted) return;
    AppFeedback.success(context, context.l10n.passwordResetSuccess);
    context.canPop() ? context.pop() : context.go(Routes.login);
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (title, subtitle) = switch (_step) {
      _Step.email => (l.forgotTitle, l.forgotSubtitle),
      _Step.link => (l.linkSentTitle, l.linkSentBody(_email.text.trim())),
      _Step.password => (l.resetTitle, l.resetSubtitle),
    };
    return AuthScaffold(
      title: title,
      subtitle: subtitle,
      showBack: true,
      compactHero: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StepIndicator(current: _step.index),
            const SizedBox(height: AppSpacing.xl),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  _Step.email => TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email(context),
                    onFieldSubmitted: (_) => _sendLink(),
                    decoration: InputDecoration(
                      labelText: l.email,
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  _Step.link => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _pasted,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.url,
                        minLines: 1,
                        maxLines: 3,
                        validator: (v) => ResetLink.tryParse(v ?? '') == null
                            ? l.invalidResetLink
                            : null,
                        decoration: InputDecoration(
                          labelText: l.pasteLinkLabel,
                          prefixIcon: const Icon(Icons.link_rounded),
                        ),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _step = _Step.email;
                                _error = null;
                              }),
                        child: Text(l.resendLink),
                      ),
                    ],
                  ),
                  _Step.password => Column(
                    children: [
                      PasswordField(
                        controller: _password,
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
                        validator: (v) =>
                            v != _password.text ? l.passwordsDontMatch : null,
                        onSubmitted: (_) => _reset(),
                      ),
                    ],
                  ),
                },
              ),
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
              loading: _loading,
              label: switch (_step) {
                _Step.email => l.sendResetLink,
                _Step.link => l.continueAction,
                _Step.password => l.resetPasswordAction,
              },
              onPressed: switch (_step) {
                _Step.email => _sendLink,
                _Step.link => _usePastedLink,
                _Step.password => _reset,
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.stepOf(current + 1, 3),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: i <= current ? AppColors.brandGradient : null,
                  color: i <= current ? null : scheme.surfaceContainerHigh,
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
