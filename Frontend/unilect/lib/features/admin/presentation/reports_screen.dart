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
import '../application/admin_providers.dart';

/// FR-074: review content reports, update status and keep a notes history.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportStatus? _status = ReportStatus.open;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reports = ref.watch(reportsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: Text(l.reportsTitle)),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                for (final s in [null, ...ReportStatus.values]) ...[
                  ChoiceChip(
                    label: Text(s == null ? l.all : l.reportStatusLabel(s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<ContentReport>>(
              value: reports,
              onRetry: () => ref.invalidate(reportsProvider(_status)),
              isEmpty: (r) => r.isEmpty,
              empty: EmptyView(
                icon: Icons.flag_outlined,
                title: l.emptyReports,
              ),
              data: (list) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return NavCard(
                    leading: const IconBadge(
                      icon: Icons.flag_rounded,
                      color: AppColors.danger,
                    ),
                    title: r.contentTitle,
                    subtitle:
                        '${l.reportReasonLabel(r.reason)} · ${l.reportedBy(r.reporter)} · ${context.formatRelative(r.createdAt)}',
                    badge: _StatusPill(status: r.status),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _ReportSheet(report: r),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    final color = switch (status) {
      ReportStatus.open => colors.danger,
      ReportStatus.inReview => colors.warning,
      ReportStatus.resolved => colors.success,
      ReportStatus.dismissed => colors.neutral,
    };
    return Pill(label: context.l10n.reportStatusLabel(status), color: color);
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.report});
  final ContentReport report;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  late ReportStatus _status = widget.report.status;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateReport(widget.report, status: _status, note: _note.text);
      ref
        ..invalidate(reportsProvider)
        ..invalidate(adminDashboardProvider);
      if (!mounted) return;
      AppFeedback.success(context, context.l10n.statusChanged);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = widget.report;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.contentTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                _StatusPill(status: r.status),
                Pill(
                  label: l.reportReasonLabel(r.reason),
                  color: AppColors.blue600,
                ),
              ],
            ),
            if (r.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.md),
              Text('“${r.note}”'),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l.reportedBy(r.reporter)} · ${context.formatDateTime(r.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push(Routes.viewer(r.contentId, manage: true));
              },
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l.previewFile),
            ),
            if (r.history.isNotEmpty) ...[
              SectionHeader(title: l.history),
              for (final h in r.history)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_rounded),
                  title: Text('${l.reportStatusLabel(h.status)} · ${h.actor}'),
                  subtitle: Text(
                    [context.formatDateTime(h.at), ?h.note].join('\n'),
                  ),
                ),
            ],
            SectionHeader(title: l.updateStatus),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in [r.status, ...r.status.next])
                  ChoiceChip(
                    label: Text(l.reportStatusLabel(s)),
                    selected: _status == s,
                    onSelected: (_) => setState(() => _status = s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: '${l.addNote} (${l.optional})',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            LoadingButton(label: l.save, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
