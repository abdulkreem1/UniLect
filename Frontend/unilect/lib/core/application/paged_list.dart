import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/json.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

/// Base notifier for server-paged lists with infinite scrolling.
abstract class PagedListNotifier<T> extends AsyncNotifier<Paged<T>> {
  bool _loadingMore = false;

  Future<Paged<T>> fetchPage(int page);

  @override
  Future<Paged<T>> build() => fetchPage(1);

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await fetchPage(current.page + 1);
      state = AsyncData(
        Paged(
          items: [...current.items, ...next.items],
          page: next.page,
          pageSize: next.pageSize,
          total: next.total,
        ),
      );
    } on Object {
      // Keep the current items; the user can scroll again to retry.
    } finally {
      _loadingMore = false;
    }
  }

  /// Replaces one item in place after a mutation (e.g. status change).
  void replaceWhere(bool Function(T item) test, T updated) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      Paged(
        items: [for (final i in current.items) test(i) ? updated : i],
        page: current.page,
        pageSize: current.pageSize,
        total: current.total,
      ),
    );
  }
}

/// List view bound to a [PagedListNotifier] provider.
class PagedListView<T> extends ConsumerStatefulWidget {
  const PagedListView({
    super.key,
    required this.provider,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = AppSpacing.page,
  });

  final AsyncNotifierProvider<PagedListNotifier<T>, Paged<T>> provider;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final Widget? header;
  final EdgeInsets padding;

  @override
  ConsumerState<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends ConsumerState<PagedListView<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(widget.provider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(widget.provider);
    Future<void> refresh() => ref.refresh(widget.provider.future);
    return AsyncValueView<Paged<T>>(
      value: value,
      onRetry: refresh,
      isEmpty: (p) => p.items.isEmpty,
      empty: widget.empty,
      data: (page) => RefreshIndicator(
        onRefresh: refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: widget.padding,
          itemCount: page.items.length + (widget.header == null ? 0 : 1) + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final offset = widget.header == null ? 0 : 1;
            if (widget.header != null && i == 0) return widget.header!;
            final index = i - offset;
            if (index == page.items.length) {
              return page.hasMore
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            return widget.itemBuilder(context, page.items[index]);
          },
        ),
      ),
    );
  }
}
