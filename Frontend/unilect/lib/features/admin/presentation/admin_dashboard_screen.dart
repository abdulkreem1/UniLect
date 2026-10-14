import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/dashboard_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../application/admin_providers.dart';
import '../domain/admin_models.dart';

/// FR-064: accounts, content and pending actions at a glance.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final data = ref.watch(adminDashboardProvider);
    Future<void> refresh() => ref.refresh(adminDashboardProvider.future);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DashboardHeader(
              title: l.adminHello,
              subtitle: user?.fullName ?? '',
            ),
            Padding(
              padding: AppSpacing.page,
              child: switch (data) {
                AsyncData(:final value) => _Body(data: value),
                AsyncError(:final error) => ErrorView(
                  error: error,
                  onRetry: refresh,
                ),
                _ => const Column(
                  children: [
                    SizedBox(height: AppSpacing.lg),
                    Skeleton(height: 90, radius: 20),
                    SizedBox(height: AppSpacing.md),
                    Skeleton(height: 260, radius: 20),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final AdminDashboard data;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).extension<StatusColors>()!;
    Widget action(
      IconData icon,
      String label,
      int count,
      Color color,
      String route,
    ) => NavCard(
      leading: IconBadge(icon: icon, color: color),
      title: label,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pill(label: '$count', color: count > 0 ? color : colors.neutral),
          const SizedBox(width: 4),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
          ),
        ],
      ),
      onTap: () => context.go(route),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.needsAction),
        action(
          Icons.phonelink_lock_rounded,
          l.pendingDevices,
          data.pendingDeviceRequests,
          colors.warning,
          Routes.adminDevices,
        ),
        const SizedBox(height: AppSpacing.md),
        action(
          Icons.fact_check_rounded,
          l.pendingReviews,
          data.pendingReviews,
          AppColors.sky500,
          Routes.adminContent,
        ),
        const SizedBox(height: AppSpacing.md),
        action(
          Icons.flag_rounded,
          l.openReports,
          data.openReports,
          colors.danger,
          Routes.adminReports,
        ),
        SectionHeader(title: l.usersTitle),
        ResponsiveGrid(
          children: [
            StatTile(
              label: l.students,
              value: data.students,
              icon: Icons.school_rounded,
              onTap: () => context.go(Routes.adminUsers),
            ),
            StatTile(
              label: l.libraries,
              value: data.libraries,
              icon: Icons.local_library_rounded,
              color: AppColors.sky500,
              onTap: () => context.go(Routes.adminUsers),
            ),
            StatTile(
              label: l.admins,
              value: data.admins,
              icon: Icons.admin_panel_settings_rounded,
              color: AppColors.blue700,
            ),
            StatTile(
              label: l.disabledAccounts,
              value: data.disabledUsers,
              icon: Icons.block_rounded,
              color: colors.danger,
            ),
          ],
        ),
        SectionHeader(title: l.contentOverview),
        ResponsiveGrid(
          children: [
            StatTile(
              label: l.statusPublished,
              value: data.content.published,
              icon: Icons.public_rounded,
              color: colors.success,
            ),
            StatTile(
              label: l.statusDraft,
              value: data.content.draft,
              icon: Icons.edit_note_rounded,
              color: colors.info,
            ),
            StatTile(
              label: l.statusArchived,
              value: data.content.archived,
              icon: Icons.inventory_2_outlined,
              color: colors.neutral,
            ),
            StatTile(
              label: l.statusPendingReview,
              value: data.content.pendingReview,
              icon: Icons.schedule_rounded,
              color: colors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
