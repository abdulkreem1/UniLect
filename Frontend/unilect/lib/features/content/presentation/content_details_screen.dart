import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../reports/domain/content_report.dart';
import '../application/student_content_providers.dart';
import '../domain/content.dart';
import 'widgets/content_widgets.dart';

/// FR-033: metadata is shown before the file is opened. Also hosts favorites
/// (FR-034) and reporting (FR-073).
class ContentDetailsScreen extends ConsumerWidget {
  const ContentDetailsScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final content = ref.watch(contentDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.contentDetails),
        actions: [
          if (content.value case final c?) ...[
            _FavoriteButton(content: c),
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (_) => _report(context, ref, c),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l.reportContent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: AsyncValueView<Content>(
        value: content,
        onRetry: () => ref.invalidate(contentDetailProvider(id)),
        data: (c) => _Body(content: c),
      ),
      bottomNavigationBar: content.value == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: GradientButton(
                label: l.openFile,
                icon: Icons.visibility_rounded,
                onPressed: content.value!.file?.isViewable ?? false
                    ? () => context.push(Routes.viewer(id))
                    : null,
              ),
            ),
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref, Content c) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReportSheet(contentId: c.id),
    );
    if ((sent ?? false) && context.mounted) {
      AppFeedback.success(context, context.l10n.reportSubmitted);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.content});
  final Content content;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = content.classification;
    final rows = <(IconData, String, String)>[
      (Icons.account_balance_outlined, l.university, c.universityName),
      (Icons.domain_outlined, l.faculty, c.facultyName),
      (Icons.layers_outlined, l.year, c.yearName),
      (Icons.menu_book_outlined, l.subject, c.subjectName),
      if (c.doctorName != null)
        (Icons.person_outline_rounded, l.doctor, c.doctorName!),
      if (c.categoryName != null)
        (Icons.category_outlined, l.category, c.categoryName!),
      if (content.examYear != null)
        (Icons.event_outlined, l.examYear, '${content.examYear}'),
      if (c.termName != null) (Icons.date_range_outlined, l.term, c.termName!),
      if (c.examTypeName != null)
        (Icons.fact_check_outlined, l.examType, c.examTypeName!),
    ];
    return ListView(
      padding: AppSpacing.page,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ContentTypeBadge(content: content, size: 56),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Pill(
                            label: l.contentTypeLabel(content.type),
                            color: theme.colorScheme.primary,
                          ),
                          if (content.lectureNumber != null)
                            Pill(
                              label: l.lectureNumber(content.lectureNumber!),
                              color: AppColors.sky500,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(content.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.addedOn(
                    context.formatDate(
                      content.publishedAt ?? content.createdAt,
                    ),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (content.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    content.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
              ],
            ),
          ),
        ),
        SectionHeader(title: l.classification),
        Card(
          child: Column(
            children: [
              for (final (i, (icon, label, value)) in rows.indexed) ...[
                if (i > 0) const Divider(indent: 56),
                ListTile(
                  leading: Icon(icon, color: theme.colorScheme.primary),
                  title: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  subtitle: Text(value, style: theme.textTheme.bodyLarge),
                ),
              ],
            ],
          ),
        ),
        SectionHeader(title: l.fileInfo),
        Card(
          child: switch (content.file) {
            final file? => ListTile(
              leading: Icon(
                file.isImage
                    ? Icons.image_outlined
                    : Icons.picture_as_pdf_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(file.isImage ? l.formatImage : l.formatPdf),
              subtitle: Text(context.formatBytes(file.sizeBytes)),
              trailing: Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            null => ListTile(
              leading: const Icon(Icons.hourglass_empty_rounded),
              title: Text(l.noFileYet),
            ),
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.protectionNote,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.content});
  final Content content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(favoritesControllerProvider);
    final isFav = ref
        .read(favoritesControllerProvider.notifier)
        .isFavorite(content.id, fallback: content.isFavorite);
    return IconButton(
      tooltip: isFav ? l.removeFromFavorites : l.addToFavorites,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFav),
          color: isFav ? AppColors.danger : null,
        ),
      ),
      onPressed: () async {
        try {
          await ref.read(favoritesControllerProvider.notifier).toggle(content);
          if (context.mounted) {
            AppFeedback.success(
              context,
              isFav ? l.removedFromFavorites : l.addedToFavorites,
            );
          }
        } catch (e) {
          if (context.mounted) AppFeedback.error(context, e);
        }
      },
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.contentId});
  final String contentId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(contentRepositoryProvider)
          .report(widget.contentId, _reason!, _note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        AppFeedback.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.reportTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          RadioGroup<ReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final r in ReportReason.values)
                  RadioListTile<ReportReason>(
                    value: r,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.reportReasonLabel(r)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: '${l.reportNote} (${l.optional})',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LoadingButton(
            label: l.sendReport,
            loading: _sending,
            onPressed: _reason == null ? null : _send,
          ),
        ],
      ),
    );
  }
}
