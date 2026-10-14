import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Form field that opens a searchable bottom-sheet list. Works for long
/// academic lists where a dropdown would be unusable.
class PickerField<T> extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
    this.allowClear = false,
    this.errorText,
    this.icon,
    this.validator,
  });

  final String label;
  final List<PickerOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool loading;
  final bool allowClear;
  final String? errorText;
  final IconData? icon;
  final String? Function(T? value)? validator;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    return FormField<T>(
      initialValue: value,
      validator: validator == null ? null : (_) => validator!(value),
      builder: (state) {
        final error = errorText ?? state.errorText;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: enabled && !loading
              ? () async {
                  final picked = await _open(context);
                  if (picked != null) {
                    onChanged(picked.value);
                    state.didChange(picked.value);
                  }
                }
              : null,
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              enabled: enabled,
              prefixIcon: icon == null ? null : Icon(icon),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (allowClear && selected != null && enabled)
                  ? IconButton(
                      tooltip: context.l10n.clearFilters,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        onChanged(null);
                        state.didChange(null);
                      },
                    )
                  : const Icon(Icons.expand_more_rounded),
            ),
            child: Text(
              selected?.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Future<_Picked<T>?> _open(BuildContext context) {
    return showModalBottomSheet<_Picked<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _PickerSheet<T>(title: label, options: options, selected: value),
    );
  }
}

class _Picked<T> {
  const _Picked(this.value);
  final T value;
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.options
        .where((o) => o.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: widget.options.length > 8 ? 0.75 : 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(widget.title, style: theme.textTheme.titleLarge),
          ),
          if (widget.options.length > 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: false,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: context.l10n.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text(context.l10n.noResults))
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final o = filtered[i];
                      final isSelected = o.value == widget.selected;
                      return ListTile(
                        title: Text(o.label),
                        subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                        selected: isSelected,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, _Picked(o.value)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
