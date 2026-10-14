import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../content/presentation/widgets/content_widgets.dart';

/// Shared layout for the hierarchical browse screens (faculties, years,
/// subjects…): app bar, pull-to-refresh, async states and animated list.
class BrowseList<T> extends StatelessWidget {
  const BrowseList({
    super.key,
    required this.title,
    required this.value,
    required this.itemBuilder,
    required this.onRefresh,
    required this.empty,
    this.header,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;
  final Widget empty;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          ?header,
          Expanded(
            child: AsyncValueView<List<T>>(
              value: value,
              onRetry: onRefresh,
              isEmpty: (items) => items.isEmpty,
              empty: RefreshIndicator(
                onRefresh: onRefresh,
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(height: c.maxHeight, child: empty),
                  ),
                ),
              ),
              data: (items) => RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.page,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) => FadeInItem(
                    index: i,
                    child: itemBuilder(context, items[i]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
