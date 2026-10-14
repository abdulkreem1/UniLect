import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/paged_list.dart';
import '../../../core/models/json.dart';
import '../../../core/providers.dart';
import '../../content/domain/content.dart';
import '../../content/domain/content_draft.dart';

/// Content counts within the manager's scope (FR-062).
final manageStatsProvider = FutureProvider.autoDispose<ContentStats>(
  (ref) => ref.watch(manageContentRepositoryProvider).stats(),
);

/// Paged content list for the library/admin manager (FR-061, FR-065).
class ManageListController extends PagedListNotifier<Content> {
  ManageListController(this.query);

  final ManageQuery query;

  @override
  Future<Paged<Content>> fetchPage(int page) =>
      ref.read(manageContentRepositoryProvider).list(query, page: page);
}

final manageListProvider = AsyncNotifierProvider.autoDispose
    .family<ManageListController, Paged<Content>, ManageQuery>(
      ManageListController.new,
    );

final manageContentProvider = FutureProvider.autoDispose
    .family<Content, String>(
      (ref, id) => ref.watch(manageContentRepositoryProvider).get(id),
    );

final contentVersionsProvider = FutureProvider.autoDispose
    .family<List<ContentVersion>, String>(
      (ref, id) => ref.watch(manageContentRepositoryProvider).versions(id),
    );

/// Call after any content mutation so dashboards and lists refresh.
void invalidateManagedContent(WidgetRef ref) {
  ref
    ..invalidate(manageStatsProvider)
    ..invalidate(manageListProvider);
}
