import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../content/domain/content.dart';
import '../../content/domain/content_draft.dart';
import '../../settings/application/config_providers.dart';
import '../application/manage_providers.dart';
import '../data/file_picker_service.dart';
import '../domain/upload_validation.dart';
import 'widgets/classification_fields.dart';

enum _ItemState { pending, uploading, success, failed }

class _BatchItem {
  _BatchItem(this.file, {required String title, this.lectureNumber})
    : title = TextEditingController(text: title);

  final UploadFile file;
  final TextEditingController title;
  int? lectureNumber;
  _ItemState state = _ItemState.pending;
  double progress = 0;
  String? error;
}

/// FR-063: upload several files with a shared classification; each file's
/// success or failure is reported independently.
class BatchUploadScreen extends ConsumerStatefulWidget {
  const BatchUploadScreen({super.key});

  @override
  ConsumerState<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends ConsumerState<BatchUploadScreen> {
  ContentDraft _common = const ContentDraft(type: ContentType.lecture);
  final _items = <_BatchItem>[];
  bool _publish = false;
  bool _running = false;
  bool _showErrors = false;

  @override
  void dispose() {
    for (final i in _items) {
      i.title.dispose();
    }
    super.dispose();
  }

  void _setType(ContentType type) => setState(() {
    _common = ContentDraft(
      type: type,
      universityId: _common.universityId,
      facultyId: _common.facultyId,
      yearId: _common.yearId,
      subjectId: _common.subjectId,
      doctorId: _common.doctorId,
    );
  });

  Future<void> _addFiles() async {
    final config = await ref.read(clientConfigProvider.future);
    final picked = await ref
        .read(filePickerServiceProvider)
        .pick(extensions: config.allowedExtensions, multiple: true);
    if (!mounted) return;
    final l = context.l10n;
    var next =
        _items
            .map((i) => i.lectureNumber ?? 0)
            .fold(0, (a, b) => a > b ? a : b) +
        1;
    setState(() {
      for (final f in picked) {
        final dot = f.name.lastIndexOf('.');
        final item = _BatchItem(
          f,
          title: dot > 0 ? f.name.substring(0, dot) : f.name,
          lectureNumber: _common.type == ContentType.lecture ? next++ : null,
        );
        final problem = checkUpload(f, config);
        if (problem != null) {
          item
            ..state = _ItemState.failed
            ..error = switch (problem) {
              FileTypeNotAllowed(:final extension) => l.fileTypeNotAllowed(
                extension,
              ),
              FileTooLarge(:final maxMb) => l.fileTooLarge(maxMb),
            };
        }
        _items.add(item);
      }
    });
  }

  Future<void> _uploadAll({bool onlyFailed = false}) async {
    final missing = _publish
        ? _common.copyWith(title: 'x').missingForPublish()
        : {if (_common.subjectId == null) DraftField.subject};
    if (missing.isNotEmpty) {
      setState(() => _showErrors = true);
      AppFeedback.error(
        context,
        context.l10n.missingForPublish(describeMissing(context, missing)),
      );
      return;
    }
    setState(() => _running = true);
    final repo = ref.read(manageContentRepositoryProvider);
    final config = await ref.read(clientConfigProvider.future);
    for (final item in _items) {
      final eligible = onlyFailed
          ? item.state == _ItemState.failed
          : item.state == _ItemState.pending;
      if (!eligible || checkUpload(item.file, config) != null) continue;
      setState(() {
        item
          ..state = _ItemState.uploading
          ..progress = 0
          ..error = null;
      });
      try {
        await repo.create(
          draft: _common.copyWith(
            title: item.title.text,
            lectureNumber: Nullable(item.lectureNumber),
          ),
          file: item.file,
          publish: _publish,
          onProgress: (p) => setState(() => item.progress = p),
        );
        if (mounted) setState(() => item.state = _ItemState.success);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          item
            ..state = _ItemState.failed
            ..error = context.failureMessage(e);
        });
      }
    }
    invalidateManagedContent(ref);
    if (!mounted) return;
    setState(() => _running = false);
    final ok = _items.where((i) => i.state == _ItemState.success).length;
    final failed = _items.where((i) => i.state == _ItemState.failed).length;
    AppFeedback.info(context, context.l10n.batchSummary(ok, failed));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final failed = _items.where((i) => i.state == _ItemState.failed).length;
    final pending = _items.where((i) => i.state == _ItemState.pending).length;
    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(title: Text(l.batchTitle)),
        body: AbsorbPointer(
          absorbing: _running,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                l.batchSubtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<ContentType>(
                segments: [
                  ButtonSegment(
                    value: ContentType.lecture,
                    label: Text(l.lectures),
                    icon: const Icon(Icons.menu_book_rounded),
                  ),
                  ButtonSegment(
                    value: ContentType.exam,
                    label: Text(l.exams),
                    icon: const Icon(Icons.quiz_rounded),
                  ),
                ],
                selected: {_common.type},
                onSelectionChanged: _items.isEmpty
                    ? (s) => _setType(s.first)
                    : null,
              ),
              SectionHeader(title: l.commonClassification),
              ClassificationFields(
                draft: _common,
                showErrors: _showErrors,
                onChanged: (d) => setState(() => _common = d),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_common.type == ContentType.lecture)
                LectureFields(
                  draft: _common,
                  showErrors: _showErrors && _publish,
                  onChanged: (d) => setState(() => _common = d),
                )
              else ...[
                ExamFields(
                  draft: _common,
                  showErrors: _showErrors && _publish,
                  onChanged: (d) => setState(() => _common = d),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.publishAfterUpload),
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
              ),
              SectionHeader(
                title: l.filesToUpload(_items.length),
                action: TextButton.icon(
                  onPressed: _addFiles,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.addFiles),
                ),
              ),
              if (_items.isEmpty)
                NavCard(
                  leading: const IconBadge(
                    icon: Icons.drive_folder_upload_rounded,
                    gradient: true,
                  ),
                  title: l.addFiles,
                  subtitle: l.tapToChooseFile,
                  onTap: _addFiles,
                ),
              for (final item in _items) ...[
                _BatchTile(
                  item: item,
                  isLecture: _common.type == ContentType.lecture,
                  onRemove: item.state == _ItemState.uploading
                      ? null
                      : () => setState(() {
                          _items.remove(item);
                          item.title.dispose();
                        }),
                  onNumber: (n) => item.lectureNumber = n,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: 100),
            ],
          ),
        ),
        bottomNavigationBar: _items.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    if (failed > 0 && pending == 0) ...[
                      Expanded(
                        child: LoadingButton(
                          label: l.retryFailed,
                          outlined: true,
                          onPressed: _running
                              ? null
                              : () => _uploadAll(onlyFailed: true),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: GradientButton(
                          label: l.uploadAll,
                          icon: Icons.cloud_upload_rounded,
                          loading: _running,
                          onPressed: pending == 0 ? null : _uploadAll,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({
    required this.item,
    required this.isLecture,
    required this.onRemove,
    required this.onNumber,
  });

  final _BatchItem item;
  final bool isLecture;
  final VoidCallback? onRemove;
  final ValueChanged<int?> onNumber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final (label, color, icon) = switch (item.state) {
      _ItemState.pending => (
        l.batchPending,
        theme.colorScheme.onSurfaceVariant,
        Icons.schedule_rounded,
      ),
      _ItemState.uploading => (
        l.uploading((item.progress * 100).round()),
        AppColors.sky500,
        Icons.cloud_upload_rounded,
      ),
      _ItemState.success => (
        l.batchSuccess,
        AppColors.success,
        Icons.check_circle_rounded,
      ),
      _ItemState.failed => (
        l.batchFailed,
        AppColors.danger,
        Icons.error_rounded,
      ),
    };
    final editable =
        item.state == _ItemState.pending || item.state == _ItemState.failed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${item.file.name} · ${context.formatBytes(item.file.sizeBytes)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Pill(label: label, color: color, icon: icon),
                IconButton(
                  tooltip: l.removeFile,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: item.title,
                    enabled: editable,
                    decoration: InputDecoration(
                      labelText: l.title,
                      isDense: true,
                    ),
                  ),
                ),
                if (isLecture) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      initialValue: item.lectureNumber?.toString() ?? '',
                      enabled: editable,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '#',
                        isDense: true,
                      ),
                      onChanged: (v) => onNumber(int.tryParse(v)),
                    ),
                  ),
                ],
              ],
            ),
            if (item.state == _ItemState.uploading) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: item.progress,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            if (item.error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
