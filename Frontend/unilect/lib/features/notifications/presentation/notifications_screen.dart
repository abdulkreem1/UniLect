import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../domain/app_notification.dart';

/// FR-072 notification center (FR-070/071 deliveries land here).
class NotificationsController extends AsyncNotifier<NotificationPage> {
  @override
  Future<NotificationPage> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(notificationsRepositoryProvider).list();
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        NotificationPage(
          page: Paged(
            items: [
              for (final x in current.page.items)
                x.id == n.id ? n.markRead() : x,
            ],
            page: current.page.page,
            pageSize: current.page.pageSize,
            total: current.page.total,
          ),
          unreadCount: current.unreadCount > 0 ? current.unreadCount - 1 : 0,
        ),
      );
    }
    await ref.read(notificationsRepositoryProvider).markRead(n.id);
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    ref.invalidateSelf();
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, NotificationPage>(
      NotificationsController.new,
    );

final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsControllerProvider).value?.unreadCount ?? 0,
);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    Future<void> refresh() =>
        ref.refresh(notificationsControllerProvider.future);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(notificationsControllerProvider.notifier)
                      .markAllRead();
                } catch (e) {
                  if (context.mounted) AppFeedback.error(context, e);
                }
              },
              child: Text(l.markAllRead),
            ),
        ],
      ),
      body: AsyncValueView<NotificationPage>(
        value: state,
        onRetry: refresh,
        isEmpty: (p) => p.page.items.isEmpty,
        empty: EmptyView(
          icon: Icons.notifications_none_rounded,
          title: l.emptyNotifications,
          message: l.emptyNotificationsHint,
        ),
        data: (p) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: AppSpacing.page,
            itemCount: p.page.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _NotificationTile(
              notification: p.page.items[i],
              onTap: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .markRead(p.page.items[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;
    final (icon, color) = switch (n.type) {
      NotificationType.deviceChangeApproved => (
        Icons.verified_user_rounded,
        AppColors.success,
      ),
      NotificationType.deviceChangeRejected => (
        Icons.gpp_bad_rounded,
        AppColors.danger,
      ),
      NotificationType.newContent => (
        Icons.auto_stories_rounded,
        AppColors.sky500,
      ),
      NotificationType.contentReviewed => (
        Icons.fact_check_rounded,
        AppColors.blue600,
      ),
      NotificationType.reportUpdated => (Icons.flag_rounded, AppColors.warning),
      NotificationType.system => (Icons.campaign_rounded, AppColors.blue600),
    };
    return Card(
      color: n.isRead
          ? null
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: n.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(n.body, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.formatRelative(n.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Semantics(
                  label: 'unread',
                  child: Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
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
