import 'package:dio/dio.dart';

import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../../reports/domain/content_report.dart';
import '../domain/content.dart';

/// Student-facing content access. The server only ever returns published
/// content inside an active academic path (FR-079); the client never filters
/// for security purposes.
class ContentRepository {
  ContentRepository(this._api);

  final ApiClient _api;

  static const _contents = '/catalog/contents/';

  /// Published lectures of a course, by lecture number then newest.
  Future<List<Content>> lectures(String subjectId, {String? doctorId}) =>
      _api.getAll(
        _contents,
        Content.fromJson,
        query: {'kind': 'lecture', 'course': subjectId, 'instructor': doctorId},
      );

  Future<List<Content>> exams(String subjectId, ExamFilter filter) =>
      _api.getAll(
        _contents,
        Content.fromJson,
        query: {
          'kind': 'exam',
          'course': subjectId,
          'ordering': '-exam_year',
          ...filter.toQuery(),
        },
      );

  Future<Paged<Content>> search(ContentQuery query, {int page = 1}) => _api
      .getPage(_contents, Content.fromJson, page: page, query: query.toQuery());

  Future<Content> detail(String id) async =>
      Content.fromJson(await _api.get<Json>('$_contents$id/'));

  /// Authorized, in-memory file stream for the secure viewer (FR-056).
  Future<FileBytes> file(String id, {CancelToken? cancelToken}) =>
      _api.getFile('$_contents$id/file/', cancelToken: cancelToken);

  /// Favorites that are still visible; others silently drop out (FR-034).
  Future<List<Content>> favorites() => _api.getAll(
    '/me/favorites/',
    (json) =>
        Content.fromJson(json['content_detail'] as Json)
            .copyWith(isFavorite: true),
  );

  /// Adding is idempotent on the server.
  Future<void> setFavorite(String contentId, {required bool favorite}) =>
      favorite
      ? _api.post<Json>('/me/favorites/', body: {'content': contentId})
      : _api.delete('/me/favorites/$contentId/');

  Future<Set<String>> followedSubjects() async => {
    for (final f in await _follows()) idOf(f['course']),
  };

  /// Follows a course with new-content notifications on (FR-071), or stops
  /// following it.
  Future<void> setFollowSubject(
    String subjectId, {
    required bool follow,
  }) async {
    if (follow) {
      await _api.post<Json>(
        '/me/followed-courses/',
        body: {'course': intId(subjectId), 'notify_new_content': true},
      );
      return;
    }
    for (final f in await _follows()) {
      if (idOf(f['course']) == subjectId) {
        await _api.delete('/me/followed-courses/${f['id']}/');
      }
    }
  }

  Future<List<Json>> _follows() =>
      _api.getAll('/me/followed-courses/', (json) => json);

  /// One open report per student and item; a second one is refused with
  /// `report_already_open` (FR-073).
  Future<void> report(String contentId, ReportReason reason, String? note) =>
      _api.post<Json>(
        '$_contents$contentId/reports/',
        body: {'reason': reason.apiValue, 'message': note?.trim() ?? ''},
      );
}
