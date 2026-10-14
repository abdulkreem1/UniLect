import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../domain/content.dart';
import '../domain/content_draft.dart';

/// Content management for library staff (own in-scope content, FR-060) and
/// administrators (everything, FR-065). Out-of-scope ids answer 404.
///
/// Workflow (FR-042, FR-066): `draft` → [submit] → `published`, or
/// `pending_review` when review is required for libraries → [approve] /
/// [reject]; any non-archived item → [archive] → [restore] → `draft`.
class ManageContentRepository {
  ManageContentRepository(this._api);

  final ApiClient _api;

  static const _contents = '/manage/contents/';

  Future<Paged<Content>> list(ManageQuery query, {int page = 1}) => _api
      .getPage(_contents, Content.fromJson, page: page, query: query.toQuery());

  Future<ContentStats> stats() async =>
      ContentStats.fromJson(await _api.get<Json>('/manage/stats/'));

  Future<Content> get(String id) async =>
      Content.fromJson(await _api.get<Json>('$_contents$id/'));

  /// Library accounts only. Created as a draft, then submitted when
  /// [publish] is set (which may end in `pending_review`).
  Future<Content> create({
    required ContentDraft draft,
    required UploadFile file,
    required bool publish,
    void Function(double progress)? onProgress,
  }) async {
    final created = Content.fromJson(
      await _api.postMultipart(
        _contents,
        file: file,
        fields: draft.toFields(),
        onProgress: onProgress,
      ),
    );
    return publish ? submit(created.id) : created;
  }

  /// Published items must stay complete; a library edit of a published item
  /// goes back to review when review is required.
  Future<Content> updateMetadata(String id, ContentDraft draft) async =>
      Content.fromJson(
        await _api.patch<Json>('$_contents$id/', body: draft.toFields()),
      );

  /// Uploads a new current version (old versions are kept).
  Future<Content> replaceFile(
    String id,
    UploadFile file, {
    void Function(double progress)? onProgress,
  }) async {
    await _api.postMultipart(
      '$_contents$id/file/',
      file: file,
      onProgress: onProgress,
    );
    return get(id);
  }

  Future<List<ContentVersion>> versions(String id) =>
      _api.getList('$_contents$id/versions/', ContentVersion.fromJson);

  /// Library: drafts only. Admin: any state.
  Future<void> delete(String id) => _api.delete('$_contents$id/');

  /// Preview stream for managers, drafts included (FR-044).
  Future<FileBytes> preview(String id) => _api.getFile('$_contents$id/file/');

  /// Requires every mandatory field and a file (`incomplete_content`).
  Future<Content> submit(String id) => _transition(id, 'submit');

  Future<Content> archive(String id) => _transition(id, 'archive');

  /// `archived` → `draft`.
  Future<Content> restore(String id) => _transition(id, 'restore');

  /// Admin review decision (FR-066).
  Future<Content> approve(String id) => _transition(id, 'approve');

  Future<Content> reject(String id, {String? note}) =>
      _transition(id, 'reject', body: {'note': note?.trim() ?? ''});

  Future<Content> _transition(String id, String action, {Json? body}) async =>
      Content.fromJson(
        await _api.post<Json>('$_contents$id/$action/', body: body),
      );
}
