import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';

/// Branded layout for unauthenticated screens: deep-navy hero with the logo
/// and a rounded sheet holding the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.showBack = false,
    this.compactHero = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final bool compactHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroHeight = compactHero ? 190.0 : 280.0;
    return Scaffold(
      backgroundColor: AppColors.navy950,
      body: Stack(
        children: [
          Container(
            height: heroHeight + 60,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: const _HeroDecoration(),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: heroHeight,
                    child: Stack(
                      children: [
                        if (showBack)
                          PositionedDirectional(
                            top: 4,
                            start: 4,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              color: Colors.white,
                              icon: const BackButtonIcon(),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppLogo(size: compactHero ? 72 : 104),
                              if (!compactHero) ...[
                                const SizedBox(height: AppSpacing.lg),
                                const AppWordmark(fontSize: 30, onDark: true),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl + 4),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDecoration extends StatelessWidget {
  const _HeroDecoration();

  @override
  Widget build(BuildContext context) {
    Widget orb(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ),
      ),
    );
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          PositionedDirectional(
            top: -60,
            end: -40,
            child: orb(240, AppColors.sky500),
          ),
          PositionedDirectional(
            top: 120,
            start: -80,
            child: orb(220, AppColors.blue600),
          ),
        ],
      ),
    );
  }
}

/// Inline informational banner (info / warning / error tone).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
  });

  final String message;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
