import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cards.dart';
import '../../domain/content.dart';

/// Status pill for the publication lifecycle.
class ContentStatusPill extends StatelessWidget {
  const ContentStatusPill(this.status, {super.key});

  final ContentStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    final (color, icon) = switch (status) {
      ContentStatus.published => (colors.success, Icons.public_rounded),
      ContentStatus.draft => (colors.neutral, Icons.edit_note_rounded),
      ContentStatus.pendingReview => (colors.warning, Icons.schedule_rounded),
      ContentStatus.archived => (colors.neutral, Icons.inventory_2_outlined),
    };
    return Pill(
      label: context.l10n.contentStatusLabel(status),
      color: color,
      icon: icon,
    );
  }
}

/// Leading visual for a content item, by type and format.
class ContentTypeBadge extends StatelessWidget {
  const ContentTypeBadge({super.key, required this.content, this.size = 52});

  final Content content;
  final double size;

  @override
  Widget build(BuildContext context) {
    final number = content.lectureNumber;
    if (content.type == ContentType.lecture && number != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return IconBadge(
      size: size,
      icon: content.type == ContentType.exam
          ? ((content.file?.isImage ?? false)
                ? Icons.image_outlined
                : Icons.quiz_outlined)
          : Icons.picture_as_pdf_outlined,
      color: content.type == ContentType.exam
          ? AppColors.sky500
          : AppColors.blue600,
    );
  }
}

/// Standard list row for a content item.
class ContentTile extends StatelessWidget {
  const ContentTile({
    super.key,
    required this.content,
    required this.onTap,
    this.showPath = false,
    this.showStatus = false,
    this.trailing,
  });

  final Content content;
  final VoidCallback onTap;
  final bool showPath;
  final bool showStatus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = content.classification;
    final meta = <String>[
      if (showPath) c.subjectName,
      if (content.type == ContentType.lecture && c.doctorName != null)
        c.doctorName!,
      if (content.type == ContentType.exam) ...[
        if (content.examYear != null) '${content.examYear}',
        ?c.examTypeName,
        ?c.termName,
      ],
      context.formatRelative(content.publishedAt ?? content.updatedAt),
    ];
    return NavCard(
      leading: ContentTypeBadge(content: content),
      title: content.title,
      subtitle: meta.join(' · '),
      onTap: onTap,
      trailing: trailing,
      badge: showStatus
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ContentStatusPill(content.status),
                Pill(
                  label: l.contentTypeLabel(content.type),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            )
          : null,
    );
  }
}

/// Staggered fade/slide-in for list items (subtle, respects reduced motion).
class FadeInItem extends StatelessWidget {
  const FadeInItem({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = (index.clamp(0, 8)) * 40;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
