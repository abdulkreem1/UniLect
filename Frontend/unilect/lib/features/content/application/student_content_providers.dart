import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/json.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/content.dart';

final lecturesProvider = FutureProvider.autoDispose
    .family<List<Content>, ({String subjectId, String? doctorId})>(
      (ref, a) => ref
          .watch(contentRepositoryProvider)
          .lectures(a.subjectId, doctorId: a.doctorId),
    );

final examsProvider = FutureProvider.autoDispose
    .family<List<Content>, ({String subjectId, ExamFilter filter})>(
      (ref, a) =>
          ref.watch(contentRepositoryProvider).exams(a.subjectId, a.filter),
    );

final contentDetailProvider = FutureProvider.autoDispose
    .family<Content, String>(
      (ref, id) => ref.watch(contentRepositoryProvider).detail(id),
    );

/// Favorites stored on the student's account (FR-034).
class FavoritesController extends AsyncNotifier<List<Content>> {
  @override
  Future<List<Content>> build() {
    // Re-load when the signed-in user changes (never leak across accounts).
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(contentRepositoryProvider).favorites();
  }

  bool isFavorite(String id, {bool fallback = false}) {
    final list = state.value;
    return list == null ? fallback : list.any((c) => c.id == id);
  }

  /// Optimistic toggle; rolls back and rethrows on failure.
  Future<void> toggle(Content content) async {
    final previous = state.value ?? const <Content>[];
    final adding = !previous.any((c) => c.id == content.id);
    state = AsyncData(
      adding
          ? [content.copyWith(isFavorite: true), ...previous]
          : previous.where((c) => c.id != content.id).toList(),
    );
    try {
      await ref
          .read(contentRepositoryProvider)
          .setFavorite(content.id, favorite: adding);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<Content>>(
      FavoritesController.new,
    );

/// Subjects the student follows for new-content notifications (FR-071).
class FollowedSubjectsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(contentRepositoryProvider).followedSubjects();
  }

  Future<bool> toggle(String subjectId) async {
    final previous = state.value ?? const <String>{};
    final follow = !previous.contains(subjectId);
    state = AsyncData(
      follow ? {...previous, subjectId} : ({...previous}..remove(subjectId)),
    );
    try {
      await ref
          .read(contentRepositoryProvider)
          .setFollowSubject(subjectId, follow: follow);
      return follow;
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

final followedSubjectsProvider =
    AsyncNotifierProvider<FollowedSubjectsController, Set<String>>(
      FollowedSubjectsController.new,
    );

/// Paged search state (FR-031, FR-032).
class SearchState {
  const SearchState({
    this.query = const ContentQuery(),
    this.results = const AsyncData(null),
    this.loadingMore = false,
  });

  final ContentQuery query;
  final AsyncValue<Paged<Content>?> results;
  final bool loadingMore;

  SearchState copyWith({
    ContentQuery? query,
    AsyncValue<Paged<Content>?>? results,
    bool? loadingMore,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class SearchController extends Notifier<SearchState> {
  Timer? _debounce;
  int _generation = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void setText(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _run(
        ContentQuery(
          text: text,
          type: state.query.type,
          universityId: state.query.universityId,
          facultyId: state.query.facultyId,
          yearId: state.query.yearId,
          subjectId: state.query.subjectId,
          doctorId: state.query.doctorId,
        ),
      );
    });
  }

  void setQuery(ContentQuery query) => _run(query);

  Future<void> retry() => _run(state.query);

  Future<void> _run(ContentQuery query) async {
    final gen = ++_generation;
    if (query.isEmpty) {
      state = SearchState(query: query);
      return;
    }
    state = state.copyWith(query: query, results: const AsyncLoading());
    try {
      final page = await ref.read(contentRepositoryProvider).search(query);
      if (gen == _generation) state = state.copyWith(results: AsyncData(page));
    } catch (e, st) {
      if (gen == _generation) {
        state = state.copyWith(results: AsyncError(e, st));
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.results.value;
    if (current == null || !current.hasMore || state.loadingMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final next = await ref
          .read(contentRepositoryProvider)
          .search(state.query, page: current.page + 1);
      if (gen != _generation) return;
      state = state.copyWith(
        loadingMore: false,
        results: AsyncData(
          Paged(
            items: [...current.items, ...next.items],
            page: next.page,
            pageSize: next.pageSize,
            total: next.total,
          ),
        ),
      );
    } catch (_) {
      if (gen == _generation) state = state.copyWith(loadingMore: false);
    }
  }
}

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );
