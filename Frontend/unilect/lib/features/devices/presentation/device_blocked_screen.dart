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
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../domain/device_models.dart';

/// FR-010 / FR-011: explains why sign-in was refused on this device and lets
/// the student file a device-change request (with an optional reason).
class DeviceBlockedScreen extends ConsumerStatefulWidget {
  const DeviceBlockedScreen({super.key, required this.mismatch});

  final DeviceMismatch mismatch;

  @override
  ConsumerState<DeviceBlockedScreen> createState() =>
      _DeviceBlockedScreenState();
}

class _DeviceBlockedScreenState extends ConsumerState<DeviceBlockedScreen> {
  final _reason = TextEditingController();
  late StudentDeviceRequest? _pending = widget.mismatch.pendingRequest;
  bool _justSubmitted = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await ref
          .read(authRepositoryProvider)
          .submitDeviceChangeRequest(
            ticket: widget.mismatch.ticket,
            reason: _reason.text,
          );
      if (mounted) {
        setState(() {
          _pending = request;
          _justSubmitted = true;
        });
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = context.failureMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final pending = _pending;
    return AuthScaffold(
      title: pending == null
          ? l.deviceBlockedTitle
          : (_justSubmitted ? l.requestSubmittedTitle : l.pendingRequestTitle),
      subtitle: pending == null
          ? l.deviceBlockedBody
          : (_justSubmitted
                ? l.requestSubmittedBody
                : l.pendingRequestBody(context.formatDate(pending.createdAt))),
      showBack: true,
      compactHero: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pending != null
            ? Column(
                key: const ValueKey('pending'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warning.withValues(alpha: 0.12),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 40,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  OutlinedButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(l.backToLogin),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('form'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.deviceHowTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          for (final (i, step) in [
                            l.deviceHowStep1,
                            l.deviceHowStep2,
                            l.deviceHowStep3,
                          ].indexed)
                            _Step(number: i + 1, text: step),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _reason,
                    maxLines: 3,
                    minLines: 2,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: '${l.reasonLabel} (${l.optional})',
                      hintText: l.reasonHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InfoBanner(
                      message: _error!,
                      icon: Icons.error_outline_rounded,
                      color: AppColors.danger,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  GradientButton(
                    label: l.submitRequest,
                    icon: Icons.send_rounded,
                    loading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
