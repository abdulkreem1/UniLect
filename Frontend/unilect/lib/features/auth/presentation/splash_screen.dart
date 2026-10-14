import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../application/session_controller.dart';

/// Shown while the stored session is verified. Routing away is handled by the
/// router guard as soon as the session state settles.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const AppLogo(size: 120),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppWordmark(fontSize: 34, onDark: true),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.appTagline,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (state is SessionRestoreFailed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    context.failureMessage(state.error),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 48),
                  ),
                  onPressed: () =>
                      ref.read(sessionControllerProvider.notifier).restore(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
              ] else
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.cyan400,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
