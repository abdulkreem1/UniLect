import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/paged_list.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../admin/application/admin_providers.dart';
import '../domain/device_models.dart';

/// FR-012/FR-067 requests (filter by status, sort by date) and FR-015 log.
class AdminDevicesScreen extends StatelessWidget {
  const AdminDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navDevices),
          bottom: TabBar(
            tabs: [
              Tab(text: l.deviceRequests),
              Tab(text: l.deviceLog),
            ],
          ),
        ),
        body: const TabBarView(children: [_RequestsTab(), _LogTab()]),
      ),
    );
  }
}

class _RequestsTab extends ConsumerStatefulWidget {
  const _RequestsTab();

  @override
  ConsumerState<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<_RequestsTab> {
  DeviceChangeStatus? _status = DeviceChangeStatus.pending;
  bool _newestFirst = true;

  Future<void> _decide(DeviceChangeRequest r, {required bool approve}) async {
    final l = context.l10n;
    final note = await AppFeedback.confirmWithNote(
      context,
      title: approve ? l.approve : l.reject,
      message: approve ? l.approveDeviceConfirm : null,
      noteLabel: l.decisionNote,
      confirmLabel: approve ? l.approve : l.reject,
      destructive: !approve,
    );
    if (note == null) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .decideDeviceRequest(r.id, approve: approve, note: note);
      ref
        ..invalidate(deviceRequestsProvider)
        ..invalidate(deviceLogProvider)
        ..invalidate(adminDashboardProvider);
      if (mounted) {
        AppFeedback.success(context, approve ? l.approved : l.rejected);
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final args = (status: _status, newestFirst: _newestFirst);
    final requests = ref.watch(deviceRequestsProvider(args));
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              for (final s in [null, ...DeviceChangeStatus.values]) ...[
                ChoiceChip(
                  label: Text(s == null ? l.all : l.deviceStatusLabel(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              ActionChip(
                avatar: Icon(
                  _newestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 18,
                ),
                label: Text(_newestFirst ? l.sortNewest : l.sortOldest),
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView<List<DeviceChangeRequest>>(
            value: requests,
            onRetry: () => ref.invalidate(deviceRequestsProvider(args)),
            isEmpty: (r) => r.isEmpty,
            empty: EmptyView(
              icon: Icons.phonelink_lock_rounded,
              title: l.emptyRequests,
            ),
            data: (list) => RefreshIndicator(
              onRefresh: () => ref.refresh(deviceRequestsProvider(args).future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _RequestCard(
                  request: list[i],
                  onApprove: () => _decide(list[i], approve: true),
                  onReject: () => _decide(list[i], approve: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final DeviceChangeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final r = request;
    final statusColor = switch (r.status) {
      DeviceChangeStatus.pending => colors.warning,
      DeviceChangeStatus.approved => colors.success,
      DeviceChangeStatus.rejected => colors.danger,
      DeviceChangeStatus.cancelled => colors.neutral,
    };
    Widget device(String label, IconData icon, String? value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value ?? '—'),
              ],
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.userName, style: theme.textTheme.titleMedium),
                ),
                Pill(label: l.deviceStatusLabel(r.status), color: statusColor),
              ],
            ),
            if (r.studentNumber != null)
              Text(r.studentNumber!, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            device(l.oldDevice, Icons.smartphone_outlined, r.oldDevice?.label),
            const SizedBox(height: AppSpacing.xs),
            device(l.newDevice, Icons.phone_iphone_rounded, r.newDevice.label),
            if (r.reason?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text('“${r.reason}”'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              l.requestedOn(context.formatDateTime(r.createdAt)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (r.decidedBy != null && r.decidedAt != null)
              Text(
                l.decidedBy(
                  r.decidedBy!.name,
                  context.formatDateTime(r.decidedAt!),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (r.decisionNote?.isNotEmpty ?? false)
              Text(
                '${l.decisionNote}: ${r.decisionNote}',
                style: theme.textTheme.bodySmall,
              ),
            if (r.status == DeviceChangeStatus.pending) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.danger,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(l.reject),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l.approve),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LogTab extends StatelessWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return PagedListView<DeviceLogEntry>(
      provider: deviceLogProvider,
      empty: EmptyView(icon: Icons.history_rounded, title: l.emptyLogs),
      itemBuilder: (context, e) {
        final icon = switch (e.action) {
          DeviceLogAction.bound => Icons.link_rounded,
          DeviceLogAction.changeRequested => Icons.swap_horiz_rounded,
          DeviceLogAction.approved => Icons.verified_rounded,
          DeviceLogAction.rejected => Icons.do_not_disturb_on_rounded,
          DeviceLogAction.cancelled => Icons.cancel_outlined,
          DeviceLogAction.unbound => Icons.link_off_rounded,
        };
        return Card(
          child: ListTile(
            leading: IconBadge(icon: icon, size: 42),
            title: Text('${l.deviceLogLabel(e.action)} · ${e.subject}'),
            subtitle: Text(
              [
                context.formatDateTime(e.createdAt),
                if (e.platform != null) e.platform == 'ios' ? 'iOS' : 'Android',
                if (e.actor != null && e.actor != e.subject) e.actor!,
                ?e.note,
              ].join('\n'),
              style: theme.textTheme.bodySmall,
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
