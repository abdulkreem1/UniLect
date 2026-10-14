import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dashboard_header.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../../content/domain/content.dart';
import '../../content/domain/content_draft.dart';
import '../../content/presentation/widgets/content_widgets.dart';
import '../application/manage_providers.dart';
import 'manage_content_screen.dart';

/// FR-061/FR-062: library dashboard with scoped stats and quick actions.
class LibraryDashboardScreen extends ConsumerWidget {
  const LibraryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(manageStatsProvider);
    final recent = ref.watch(manageListProvider(const ManageQuery()));
    final colors = Theme.of(context).extension<StatusColors>()!;

    Future<void> refresh() async {
      invalidateManagedContent(ref);
      await ref.read(manageStatsProvider.future);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DashboardHeader(
              title: l.libraryHello,
              subtitle: user?.fullName ?? '',
            ),
            Padding(
              padding: AppSpacing.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: l.contentOverview),
                  switch (stats) {
                    AsyncData(:final value) => ResponsiveGrid(
                      children: [
                        StatTile(
                          label: l.statusPublished,
                          value: value.published,
                          icon: Icons.public_rounded,
                          color: colors.success,
                        ),
                        StatTile(
                          label: l.statusDraft,
                          value: value.draft,
                          icon: Icons.edit_note_rounded,
                          color: colors.info,
                        ),
                        StatTile(
                          label: l.statusPendingReview,
                          value: value.pendingReview,
                          icon: Icons.schedule_rounded,
                          color: colors.warning,
                        ),
                        StatTile(
                          label: l.statusArchived,
                          value: value.archived,
                          icon: Icons.inventory_2_outlined,
                          color: colors.neutral,
                        ),
                      ],
                    ),
                    AsyncError(:final error) => ErrorView(
                      error: error,
                      onRetry: refresh,
                    ),
                    _ => const Skeleton(height: 120, radius: 20),
                  },
                  SectionHeader(title: l.quickActions),
                  NavCard(
                    leading: const IconBadge(
                      icon: Icons.upload_file_rounded,
                      gradient: true,
                    ),
                    title: l.uploadLecture,
                    onTap: () =>
                        context.push(Routes.newContent(ContentType.lecture)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  NavCard(
                    leading: const IconBadge(
                      icon: Icons.quiz_rounded,
                      color: AppColors.sky500,
                    ),
                    title: l.uploadExam,
                    onTap: () =>
                        context.push(Routes.newContent(ContentType.exam)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  NavCard(
                    leading: const IconBadge(
                      icon: Icons.drive_folder_upload_rounded,
                      color: AppColors.blue700,
                    ),
                    title: l.batchUpload,
                    onTap: () => context.push(Routes.batchUpload),
                  ),
                  SectionHeader(
                    title: l.recentContent,
                    action: TextButton(
                      onPressed: () => context.go(Routes.libraryContent),
                      child: Text(l.seeAll),
                    ),
                  ),
                  switch (recent) {
                    AsyncData(:final value) when value.items.isEmpty =>
                      EmptyView(
                        icon: Icons.folder_open_rounded,
                        title: l.emptyManaged,
                        message: l.emptyManagedHint,
                      ),
                    AsyncData(:final value) => Column(
                      children: [
                        for (final c in value.items.take(5)) ...[
                          ContentTile(
                            content: c,
                            showStatus: true,
                            showPath: true,
                            onTap: () => showContentActions(context, ref, c),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
                    AsyncError(:final error) => ErrorView(
                      error: error,
                      onRetry: refresh,
                    ),
                    _ => const Skeleton(height: 200, radius: 20),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
