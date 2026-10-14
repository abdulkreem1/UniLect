import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

abstract final class AppFeedback {
  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, AppColors.success);

  static void error(BuildContext context, Object error) => _show(
    context,
    error is String ? error : context.failureMessage(error),
    Icons.error_rounded,
    AppColors.danger,
  );

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, AppColors.cyan400);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    bool destructive = false,
  }) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: message == null ? null : Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      minimumSize: const Size(88, 44),
                    )
                  : FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel ?? l.confirm),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Confirmation with an optional free-text note. Returns null if cancelled.
  static Future<String?> confirmWithNote(
    BuildContext context, {
    required String title,
    String? message,
    required String noteLabel,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NoteDialog(
        title: title,
        message: message,
        noteLabel: noteLabel,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.noteLabel,
    required this.confirmLabel,
    required this.destructive,
    this.message,
  });

  final String title;
  final String? message;
  final String noteLabel;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextField(
            controller: _note,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: '${widget.noteLabel} (${context.l10n.optional})',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: widget.destructive ? scheme.error : null,
            foregroundColor: widget.destructive ? scheme.onError : null,
          ),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
