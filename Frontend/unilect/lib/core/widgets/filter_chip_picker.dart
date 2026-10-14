import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'picker_field.dart';

/// Compact filter chip that opens a single-choice sheet. Shows the selected
/// value as its label and a clear affordance when active.
class FilterChipPicker<T> extends StatelessWidget {
  const FilterChipPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<PickerOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    final active = selected != null;
    return FilterChip(
      selected: active,
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(active ? selected.label : label),
          const SizedBox(width: 4),
          Icon(
            active ? Icons.close_rounded : Icons.expand_more_rounded,
            size: 18,
          ),
        ],
      ),
      tooltip: label,
      onSelected: (_) async {
        if (active) {
          onChanged(null);
          return;
        }
        final picked = await showModalBottomSheet<T>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Flexible(
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            context.l10n.noResults,
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            for (final o in options)
                              ListTile(
                                title: Text(o.label),
                                onTap: () => Navigator.pop(context, o.value),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
