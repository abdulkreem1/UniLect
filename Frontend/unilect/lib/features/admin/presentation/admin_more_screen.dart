import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../academic/domain/academic_models.dart';
import '../../notifications/presentation/notifications_screen.dart';

class AdminMoreScreen extends ConsumerWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref.watch(unreadNotificationsProvider);
    final items = <(IconData, Color, String, String?, String)>[
      (
        Icons.folder_copy_rounded,
        AppColors.blue600,
        l.allContent,
        l.reviewQueue,
        Routes.adminContent,
      ),
      (
        Icons.flag_rounded,
        AppColors.danger,
        l.reportsTitle,
        l.reportsSubtitle,
        Routes.adminReports,
      ),
      (
        Icons.receipt_long_rounded,
        AppColors.navy800,
        l.auditLog,
        l.auditLogSubtitle,
        Routes.adminAudit,
      ),
      (
        Icons.tune_rounded,
        AppColors.sky500,
        l.settingsTitle,
        l.settingsSubtitle,
        Routes.adminSettings,
      ),
      (
        Icons.fact_check_rounded,
        AppColors.blue700,
        l.examTypes,
        null,
        Routes.adminStructureKind(StructureKind.examTypes),
      ),
      (
        Icons.notifications_rounded,
        AppColors.warning,
        l.notificationsTitle,
        unread > 0 ? '$unread' : null,
        Routes.adminNotifications,
      ),
      (
        Icons.person_rounded,
        AppColors.success,
        l.profileTitle,
        null,
        Routes.adminProfile,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.more)),
      body: ListView.separated(
        padding: AppSpacing.page,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final (icon, color, title, subtitle, route) = items[i];
          return NavCard(
            leading: IconBadge(icon: icon, color: color),
            title: title,
            subtitle: subtitle,
            onTap: () => context.push(route),
          );
        },
      ),
    );
  }
}
