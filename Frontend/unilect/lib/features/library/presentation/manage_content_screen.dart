import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/application/paged_list.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/filter_chip_picker.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../content/domain/content.dart';
import '../../content/domain/content_draft.dart';
import '../../content/presentation/widgets/content_widgets.dart';
import '../../settings/application/config_providers.dart';
import '../application/manage_providers.dart';

/// FR-061 (library, scoped) and FR-065/FR-066 (admin, all content + review).
class ManageContentScreen extends ConsumerStatefulWidget {
  const ManageContentScreen({super.key, this.adminMode = false});

  final bool adminMode;

  @override
  ConsumerState<ManageContentScreen> createState() =>
      _ManageContentScreenState();
}

class _ManageContentScreenState extends ConsumerState<ManageContentScreen> {
  ManageQuery _query = const ManageQuery();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = manageListProvider(_query);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode ? l.allContent : l.manageContent),
        actions: [
          if (!widget.adminMode)
            PopupMenuButton<String>(
              tooltip: l.add,
              icon: const Icon(Icons.add_circle_outline_rounded),
              onSelected: (v) => context.push(switch (v) {
                'exam' => Routes.newContent(ContentType.exam),
                'batch' => Routes.batchUpload,
                _ => Routes.newContent(ContentType.lecture),
              }),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'lecture', child: Text(l.uploadLecture)),
                PopupMenuItem(value: 'exam', child: Text(l.uploadExam)),
                PopupMenuItem(value: 'batch', child: Text(l.batchUpload)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) =>
                  setState(() => _query = _query.copyWith(text: v)),
              decoration: InputDecoration(
                hintText: l.search,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                if (widget.adminMode) ...[
                  FilterChip(
                    label: Text(l.reviewQueue),
                    avatar: const Icon(Icons.schedule_rounded, size: 18),
                    selected: _query.status == ContentStatus.pendingReview,
                    onSelected: (on) => setState(
                      () => _query = _query.copyWith(
                        status: Nullable(
                          on ? ContentStatus.pendingReview : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                FilterChipPicker<ContentType>(
                  label: l.contentType,
                  value: _query.type,
                  options: [
                    for (final t in ContentType.values)
                      PickerOption(t, l.contentTypeLabel(t)),
                  ],
                  onChanged: (v) => setState(
                    () => _query = _query.copyWith(type: Nullable(v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilterChipPicker<ContentStatus>(
                  label: l.statusLabel,
                  value: _query.status,
                  options: [
                    for (final s in ContentStatus.values)
                      PickerOption(s, l.contentStatusLabel(s)),
                  ],
                  onChanged: (v) => setState(
                    () => _query = _query.copyWith(status: Nullable(v)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<Content>(
              provider: provider,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              empty: EmptyView(
                icon: Icons.folder_open_rounded,
                title: l.emptyManaged,
                message: widget.adminMode ? null : l.emptyManagedHint,
              ),
              itemBuilder: (context, c) => ContentTile(
                content: c,
                showStatus: true,
                showPath: true,
                onTap: () => showContentActions(context, ref, c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing the actions allowed for [content] in its current
/// state. The server remains the authority (scope, role, mandatory fields).
Future<void> showContentActions(
  BuildContext context,
  WidgetRef ref,
  Content content,
) async {
  final l = context.l10n;
  final isAdmin = ref.read(currentUserProvider)?.role == UserRole.admin;
  final reviewRequired =
      ref.read(clientConfigProvider).value?.requireContentReview ?? false;
  final repo = ref.read(manageContentRepositoryProvider);
  final s = content.status;

  Future<void> run(Future<void> Function() action, String success) async {
    try {
      await action();
      invalidateManagedContent(ref);
      if (context.mounted) AppFeedback.success(context, success);
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }

  final publishLabel = !isAdmin && reviewRequired
      ? l.submitForReview
      : l.publish;
  final actions = <(IconData, String, Future<void> Function(), {bool danger})>[
    (
      Icons.edit_outlined,
      l.edit,
      () async => context.push(Routes.editContent(content.id)),
      danger: false,
    ),
    if (content.file != null)
      (
        Icons.visibility_outlined,
        l.previewFile,
        () async => context.push(Routes.viewer(content.id, manage: true)),
        danger: false,
      ),
    if (s == ContentStatus.pendingReview && isAdmin) ...[
      (
        Icons.check_circle_outline_rounded,
        l.approve,
        () => run(() => repo.approve(content.id), l.approved),
        danger: false,
      ),
      (
        Icons.cancel_outlined,
        l.reject,
        () async {
          final note = await AppFeedback.confirmWithNote(
            context,
            title: l.reject,
            noteLabel: l.rejectReasonHint,
            confirmLabel: l.reject,
            destructive: true,
          );
          if (note != null) {
            await run(() => repo.reject(content.id, note: note), l.rejected);
          }
        },
        danger: true,
      ),
    ],
    if (s == ContentStatus.draft)
      (
        Icons.public_rounded,
        publishLabel,
        () => run(() => repo.submit(content.id), l.statusChanged),
        danger: false,
      ),
    if (s == ContentStatus.archived)
      (
        Icons.undo_rounded,
        l.restoreDraft,
        () => run(() => repo.restore(content.id), l.statusChanged),
        danger: false,
      ),
    if (s != ContentStatus.archived)
      (
        Icons.inventory_2_outlined,
        l.archive,
        () => run(() => repo.archive(content.id), l.statusChanged),
        danger: false,
      ),
    // Library staff may only delete drafts; published work is archived.
    if (isAdmin || s == ContentStatus.draft)
      (
        Icons.delete_outline_rounded,
        l.delete,
        () async {
          final ok = await AppFeedback.confirm(
            context,
            title: l.delete,
            message: l.deleteContentConfirm,
            confirmLabel: l.delete,
            destructive: true,
          );
          if (ok) await run(() => repo.delete(content.id), l.deleted);
        },
        danger: true,
      ),
  ];

  final chosen = await showModalBottomSheet<Future<void> Function()>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ContentStatusPill(content.status),
                  if (content.reviewNote?.isNotEmpty ?? false) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('${l.reviewNote}: ${content.reviewNote}'),
                  ],
                ],
              ),
            ),
            const Divider(),
            for (final (icon, label, action, danger: danger) in actions)
              ListTile(
                leading: Icon(icon, color: danger ? scheme.error : null),
                title: Text(
                  label,
                  style: TextStyle(color: danger ? scheme.error : null),
                ),
                onTap: () => Navigator.pop(sheetContext, action),
              ),
          ],
        ),
      );
    },
  );
  await chosen?.call();
}
