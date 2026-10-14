import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../application/student_content_providers.dart';
import '../domain/content.dart';
import 'widgets/content_widgets.dart';

/// FR-034: favorites saved on the student's account.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final favorites = ref.watch(favoritesControllerProvider);
    Future<void> refresh() => ref.refresh(favoritesControllerProvider.future);
    return Scaffold(
      appBar: AppBar(title: Text(l.favoritesTitle)),
      body: AsyncValueView<List<Content>>(
        value: favorites,
        onRetry: refresh,
        isEmpty: (f) => f.isEmpty,
        empty: EmptyView(
          icon: Icons.favorite_border_rounded,
          title: l.emptyFavorites,
          message: l.emptyFavoritesHint,
        ),
        data: (list) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final c = list[i];
              return FadeInItem(
                index: i,
                child: ContentTile(
                  content: c,
                  showPath: true,
                  onTap: () => context.push(Routes.content(c.id)),
                  trailing: IconButton(
                    tooltip: l.removeFromFavorites,
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.danger,
                    ),
                    onPressed: () async {
                      try {
                        await ref
                            .read(favoritesControllerProvider.notifier)
                            .toggle(c);
                      } catch (e) {
                        if (context.mounted) AppFeedback.error(context, e);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
