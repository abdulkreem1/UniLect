import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../../content/presentation/widgets/content_widgets.dart';
import '../application/academic_providers.dart';

/// FR-024: student home — active universities, entry point to browsing.
class BrowseHomeScreen extends ConsumerWidget {
  const BrowseHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final universities = ref.watch(universitiesProvider);
    Future<void> refresh() => ref.refresh(universitiesProvider.future);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                name: user?.fullName.split(' ').first ?? '',
                onSearch: () => context.go(Routes.studentSearch),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(title: l.chooseUniversity),
              ),
            ),
            switch (universities) {
              AsyncData(:final value) when value.isEmpty => SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Icons.account_balance_outlined,
                  title: l.emptyUniversities,
                  message: l.emptyGenericHint,
                ),
              ),
              AsyncData(:final value) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.separated(
                  itemCount: value.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => FadeInItem(
                    index: i,
                    child: NavCard(
                      icon: Icons.account_balance_rounded,
                      title: value[i].name,
                      onTap: () => context.push(
                        Routes.faculties(value[i].id, value[i].name),
                      ),
                    ),
                  ),
                ),
              ),
              AsyncError(:final error) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(error: error, onRetry: refresh),
              ),
              _ => const SliverFillRemaining(child: SkeletonList(count: 4)),
            },
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name, required this.onSearch});

  final String name;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  AppLogo(size: 40, heroTag: null),
                  SizedBox(width: AppSpacing.md),
                  AppWordmark(fontSize: 22, onDark: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l.greeting(name),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l.appTagline, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                button: true,
                label: l.searchHint,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: onSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              l.searchHint,
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
