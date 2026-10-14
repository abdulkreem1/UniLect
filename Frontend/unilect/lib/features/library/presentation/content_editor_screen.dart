import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../academic/application/academic_providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../content/domain/content.dart';
import '../../content/domain/content_draft.dart';
import '../../content/presentation/widgets/content_widgets.dart';
import '../../settings/application/config_providers.dart';
import '../../settings/domain/client_config.dart';
import '../application/manage_providers.dart';
import '../data/file_picker_service.dart';
import '../domain/upload_validation.dart';
import 'widgets/classification_fields.dart';

/// Create or edit a lecture / past-exam file (FR-035..049, FR-078).
class ContentEditorScreen extends ConsumerWidget {
  const ContentEditorScreen({super.key, required this.type, this.contentId});

  final ContentType type;
  final String? contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = contentId;
    if (id == null) return _Editor(initial: ContentDraft(type: type));
    final content = ref.watch(manageContentProvider(id));
    return content.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonList(count: 5)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(manageContentProvider(id)),
        ),
      ),
      data: (c) => _Editor(initial: ContentDraft.fromContent(c), existing: c),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.initial, this.existing});

  final ContentDraft initial;
  final Content? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late ContentDraft _draft = widget.initial;
  late Content? _existing = widget.existing;
  late final _title = TextEditingController(text: _draft.title);
  late final _description = TextEditingController(text: _draft.description);
  late final _lectureNo = TextEditingController(
    text: _draft.lectureNumber?.toString() ?? '',
  );
  UploadFile? _file;
  String? _fileError;
  bool _showErrors = false;
  bool _busy = false;
  double? _progress;

  bool get _isEdit => _existing != null;
  bool get _isLecture => _draft.type == ContentType.lecture;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _lectureNo.dispose();
    super.dispose();
  }

  ContentDraft get _current =>
      _draft.copyWith(title: _title.text, description: _description.text);

  bool get _publishNeedsReview {
    final isLibrary = ref.read(currentUserProvider)?.role == UserRole.library;
    final review =
        ref.read(clientConfigProvider).value?.requireContentReview ?? false;
    return isLibrary && review;
  }

  Future<void> _pickFile(ClientConfig config) async {
    final picked = await ref
        .read(filePickerServiceProvider)
        .pick(extensions: config.allowedExtensions);
    if (picked.isEmpty || !mounted) return;
    final file = picked.first;
    final problem = checkUpload(file, config);
    setState(() {
      _fileError = switch (problem) {
        FileTypeNotAllowed(:final extension) => context.l10n.fileTypeNotAllowed(
          extension,
        ),
        FileTooLarge(:final maxMb) => context.l10n.fileTooLarge(maxMb),
        null => null,
      };
      _file = problem == null ? file : null;
    });
    if (problem == null && _isEdit) await _replaceFile(file);
  }

  Future<void> _replaceFile(UploadFile file) async {
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      final updated = await ref
          .read(manageContentRepositoryProvider)
          .replaceFile(
            _existing!.id,
            file,
            onProgress: (p) => setState(() => _progress = p),
          );
      ref.invalidate(contentVersionsProvider(updated.id));
      invalidateManagedContent(ref);
      if (!mounted) return;
      setState(() {
        _existing = updated;
        _file = null;
      });
      AppFeedback.success(context, context.l10n.fileReplaced);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  /// Returns true when valid; otherwise shows errors.
  bool _validate({required bool publish}) {
    final draft = _current;
    final missing = publish
        ? draft.missingForPublish()
        : draft.missingForSave();
    final needsFile = !_isEdit && _file == null;
    setState(() {
      _showErrors = true;
      if (needsFile) _fileError = context.l10n.fileRequired;
    });
    if (missing.isNotEmpty) {
      AppFeedback.error(
        context,
        context.l10n.missingForPublish(describeMissing(context, missing)),
      );
    }
    return missing.isEmpty && !needsFile;
  }

  Future<void> _save({required bool publish}) async {
    if (!_validate(publish: publish)) return;
    final l = context.l10n;
    if (publish && !_isEdit) {
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _PreviewPage(
            draft: _current,
            file: _file!,
            publishLabel: _publishNeedsReview ? l.submitForReview : l.publish,
          ),
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _busy = true;
      _progress = _isEdit ? null : 0;
    });
    final repo = ref.read(manageContentRepositoryProvider);
    try {
      Content saved;
      if (_isEdit) {
        saved = await repo.updateMetadata(_existing!.id, _current);
        if (publish && saved.status == ContentStatus.archived) {
          saved = await repo.restore(saved.id);
        }
        if (publish && saved.status == ContentStatus.draft) {
          saved = await repo.submit(saved.id);
        }
      } else {
        saved = await repo.create(
          draft: _current,
          file: _file!,
          publish: publish,
          onProgress: (p) => setState(() => _progress = p),
        );
      }
      invalidateManagedContent(ref);
      ref.invalidate(manageContentProvider(saved.id));
      if (!mounted) return;
      AppFeedback.success(context, switch (saved.status) {
        ContentStatus.published => l.publishedSuccess,
        ContentStatus.pendingReview => l.sentForReview,
        _ => l.savedSuccess,
      });
      context.pop();
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() => _showErrors = true);
      AppFeedback.error(context, f);
    } catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final config = ref.watch(clientConfigProvider);
    final existing = _existing;
    final title = _isEdit
        ? l.editContent
        : (_isLecture ? l.newLecture : l.newExam);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              if (existing != null) ...[
                Row(
                  children: [
                    ContentStatusPill(existing.status),
                    const SizedBox(width: AppSpacing.sm),
                    Pill(
                      label: l.contentTypeLabel(existing.type),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                if (existing.reviewNote?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  InfoBanner(
                    message: '${l.reviewNote}: ${existing.reviewNote}',
                    color: AppColors.warning,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_publishNeedsReview) ...[
                InfoBanner(
                  message: l.reviewRequiredNote,
                  icon: Icons.fact_check_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              // ── File ──
              SectionHeader(title: l.file),
              config.when(
                loading: () => const Skeleton(height: 96, radius: 20),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(clientConfigProvider),
                ),
                data: (cfg) => _FileCard(
                  config: cfg,
                  file: _file,
                  existing: existing,
                  error: _fileError,
                  progress: _progress,
                  onPick: () => _pickFile(cfg),
                  onPreviewExisting: existing == null
                      ? null
                      : () => context.push(
                          Routes.viewer(existing.id, manage: true),
                        ),
                ),
              ),
              // ── Metadata ──
              SectionHeader(title: l.description),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l.title,
                  errorText: _showErrors && _title.text.trim().isEmpty
                      ? l.fieldRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: '${l.description} (${l.optional})',
                  alignLabelWithHint: true,
                ),
              ),
              // ── Classification ──
              SectionHeader(title: l.classification),
              ClassificationFields(
                draft: _draft,
                showErrors: _showErrors,
                onChanged: (d) => setState(() => _draft = d),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isLecture)
                TextField(
                  controller: _lectureNo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: '${l.lectureOrder} (${l.optional})',
                    helperText: l.lectureOrderHint,
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                  ),
                  onChanged: (v) => _draft = _draft.copyWith(
                    lectureNumber: Nullable(int.tryParse(v.trim())),
                  ),
                ),
              if (_isLecture) ...[
                const SizedBox(height: AppSpacing.md),
                LectureFields(
                  draft: _draft,
                  showErrors: _showErrors,
                  onChanged: (d) => setState(() => _draft = d),
                ),
              ] else
                ExamFields(
                  draft: _draft,
                  showErrors: _showErrors,
                  onChanged: (d) => setState(() => _draft = d),
                ),
              if (existing != null) _VersionsSection(contentId: existing.id),
              const SizedBox(height: 120),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: LoadingButton(
                  label: _isEdit ? l.saveChanges : l.saveDraft,
                  outlined: true,
                  loading: _busy && _progress == null && !_isEdit,
                  onPressed: _busy ? null : () => _save(publish: false),
                ),
              ),
              if (existing?.status != ContentStatus.published &&
                  existing?.status != ContentStatus.pendingReview) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GradientButton(
                    label: _isEdit
                        ? (_publishNeedsReview ? l.submitForReview : l.publish)
                        : l.preview,
                    icon: _isEdit
                        ? Icons.public_rounded
                        : Icons.preview_rounded,
                    loading: _busy,
                    onPressed: () => _save(publish: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.config,
    required this.file,
    required this.existing,
    required this.error,
    required this.progress,
    required this.onPick,
    this.onPreviewExisting,
  });

  final ClientConfig config;
  final UploadFile? file;
  final Content? existing;
  final String? error;
  final double? progress;
  final VoidCallback onPick;
  final VoidCallback? onPreviewExisting;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = existing?.file;
    final hasFile = file != null || current != null;
    final name = file?.name ?? current?.originalName ?? '';
    final size = file?.sizeBytes ?? current?.sizeBytes ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: hasFile
              ? scheme.surface
              : scheme.primaryContainer.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(
              color: error != null
                  ? scheme.error
                  : scheme.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: progress == null ? onPick : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  IconBadge(
                    icon: hasFile
                        ? Icons.description_rounded
                        : Icons.cloud_upload_rounded,
                    gradient: !hasFile,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFile ? name : l.tapToChooseFile,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasFile
                              ? [
                                  context.formatBytes(size),
                                  if (current != null && file == null)
                                    l.versionN(current.version),
                                ].join(' · ')
                              : l.allowedTypesInfo(
                                  config.allowedExtensions.join(', '),
                                  config.maxUploadSizeMb,
                                ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasFile)
                    TextButton(
                      onPressed: progress == null ? onPick : null,
                      child: Text(
                        current != null ? l.replaceFile : l.chooseFile,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.uploading((progress! * 100).round()),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(error!, style: TextStyle(color: scheme.error)),
        ],
        if (onPreviewExisting != null && current != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onPreviewExisting,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(l.previewFile),
            ),
          ),
      ],
    );
  }
}

class _VersionsSection extends ConsumerWidget {
  const _VersionsSection({required this.contentId});
  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final versions = ref.watch(contentVersionsProvider(contentId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.versions),
        switch (versions) {
          AsyncData(:final value) => Card(
            child: Column(
              children: [
                for (final v in value)
                  ListTile(
                    leading: CircleAvatar(child: Text('${v.version}')),
                    title: Text(
                      v.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${context.formatDateTime(v.uploadedAt)} · ${v.uploadedBy} · ${context.formatBytes(v.sizeBytes)}',
                    ),
                    trailing: v.isCurrent
                        ? Pill(
                            label: l.currentVersion,
                            color: AppColors.success,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          AsyncError(:final error) => Text(context.failureMessage(error)),
          _ => const Skeleton(height: 72, radius: 20),
        },
      ],
    );
  }
}

/// FR-044: review classification and the actual file before publishing.
class _PreviewPage extends ConsumerWidget {
  const _PreviewPage({
    required this.draft,
    required this.file,
    required this.publishLabel,
  });

  final ContentDraft draft;
  final UploadFile file;
  final String publishLabel;

  String? _name<T>(
    AsyncValue<List<T>> list,
    String? id,
    String Function(T) idOf,
    String Function(T) nameOf,
  ) {
    for (final e in list.value ?? <T>[]) {
      if (idOf(e) == id) return nameOf(e);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final rows = <(String, String?)>[
      (l.contentType, l.contentTypeLabel(draft.type)),
      (l.title, draft.title),
      if (draft.description.isNotEmpty) (l.description, draft.description),
      (
        l.university,
        _name(
          ref.watch(universitiesProvider),
          draft.universityId,
          (e) => e.id,
          (e) => e.name,
        ),
      ),
      if (draft.universityId != null)
        (
          l.faculty,
          _name(
            ref.watch(facultiesProvider(draft.universityId!)),
            draft.facultyId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.facultyId != null)
        (
          l.year,
          _name(
            ref.watch(yearsProvider(draft.facultyId!)),
            draft.yearId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.yearId != null)
        (
          l.subject,
          _name(
            ref.watch(
              subjectsProvider((yearId: draft.yearId!, specializationId: null)),
            ),
            draft.subjectId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.subjectId != null && draft.doctorId != null)
        (
          l.doctor,
          _name(
            ref.watch(doctorsProvider(draft.subjectId!)),
            draft.doctorId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.lectureNumber != null)
        (l.lectureOrder, '${draft.lectureNumber}'),
      if (draft.examYear != null) (l.examYear, '${draft.examYear}'),
      if (draft.categoryId != null)
        (
          l.category,
          _name(
            ref.watch(lectureCategoriesProvider),
            draft.categoryId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.termId != null && draft.facultyId != null)
        (
          l.term,
          _name(
            ref.watch(termsProvider(draft.facultyId!)),
            draft.termId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      if (draft.examTypeId != null)
        (
          l.examType,
          _name(
            ref.watch(examTypesProvider),
            draft.examTypeId,
            (e) => e.id,
            (e) => e.name,
          ),
        ),
      (l.file, '${file.name} · ${context.formatBytes(file.sizeBytes)}'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.previewTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          Text(
            l.previewSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Column(
              children: [
                for (final (label, value) in rows)
                  ListTile(
                    dense: true,
                    title: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      value ?? '—',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(title: l.previewFile),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(height: 420, child: _LocalFilePreview(file: file)),
          ),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GradientButton(
          label: publishLabel,
          icon: Icons.public_rounded,
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
    );
  }
}

class _LocalFilePreview extends StatefulWidget {
  const _LocalFilePreview({required this.file});
  final UploadFile file;

  @override
  State<_LocalFilePreview> createState() => _LocalFilePreviewState();
}

class _LocalFilePreviewState extends State<_LocalFilePreview> {
  late final Future<Uint8List> _bytes = widget.file.readBytes();

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final ext = file.extension;
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        final bytes = snap.data;
        if (snap.hasError) return ErrorView(error: snap.error!);
        if (bytes == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ext == 'pdf'
            ? PdfViewer.data(
                bytes,
                sourceName: 'local-preview-${file.name}-${file.sizeBytes}',
                params: const PdfViewerParams(
                  backgroundColor: AppColors.navy950,
                  margin: 8,
                ),
              )
            : ColoredBox(
                color: AppColors.navy950,
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              );
      },
    );
  }
}
