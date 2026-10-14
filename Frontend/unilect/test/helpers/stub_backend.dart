import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:unilect/core/models/json.dart';

/// A canned answer of the [StubBackend].
class StubResponse {
  const StubResponse(this.status, [this.body, this.headers = const {}]);

  final int status;

  /// JSON-encodable body, or raw bytes for file endpoints.
  final Object? body;
  final Map<String, List<String>> headers;
}

typedef StubHandler = FutureOr<StubResponse> Function(RequestOptions request);

/// In-process HTTP transport for widget tests. Routes are matched on method
/// and path below `/api/v1` (query parameters are available to handlers);
/// unknown routes answer the API's 404 envelope. Every request is recorded.
class StubBackend implements HttpClientAdapter {
  final _routes = <String, StubHandler>{};
  final requests = <RequestOptions>[];

  void on(String method, String path, StubHandler handler) =>
      _routes['$method $path'] = handler;

  void json(String method, String path, Object? body, {int status = 200}) =>
      on(method, path, (_) => StubResponse(status, body));

  /// Requests sent to [path] (optionally with [method]).
  List<RequestOptions> sent(String path, {String? method}) => [
    for (final r in requests)
      if (_path(r) == path && (method == null || r.method == method)) r,
  ];

  static String _path(RequestOptions r) =>
      r.uri.path.replaceFirst(RegExp(r'^/api/v1'), '');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = _routes['${options.method} ${_path(options)}'];
    final response = handler == null
        ? StubResponse(404, apiError('not_found', 'Not found.'))
        : await handler(options);
    final body = response.body;
    if (body is List<int>) {
      return ResponseBody.fromBytes(
        body,
        response.status,
        headers: response.headers,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// ── Backend-shaped fixtures ─────────────────────────────────────────────────

Json apiError(String code, String message, [Json details = const {}]) => {
  'error': {'code': code, 'message': message, 'details': details},
};

/// DRF page `{count, next, previous, results}`.
Json page(List<Json> results) => {
  'count': results.length,
  'next': null,
  'previous': null,
  'results': results,
};

Json userJson({
  required String role,
  String id = '11111111-1111-1111-1111-111111111111',
  String name = 'أحمد خالد',
  String email = 'student@unilect.test',
  bool mustChangePassword = false,
  bool isActive = true,
  String? studentNumber,
  int? university,
  int? library,
}) => {
  'id': id,
  'email': email,
  'full_name': name,
  'phone': '',
  'role': role,
  'student_number': studentNumber,
  'university': university,
  'university_name': university == null ? null : 'جامعة دمشق',
  'library': library,
  'library_name': library == null ? null : 'مكتبة الهندسة - دمشق',
  'must_change_password': mustChangePassword,
  'is_active': isActive,
  'date_joined': '2026-09-01T09:00:00Z',
};

Json loginResponse(Json user) => {
  'access': 'access-token',
  'refresh': 'refresh-token',
  'token_type': 'Bearer',
  'access_expires_in': 600,
  'refresh_expires_in': 2592000,
  'user': user,
};

Json ref(int id, String name) => {'id': id, 'name': name};

/// A content item as `catalog/contents/` returns it.
Json catalogContent({
  required String id,
  required String title,
  String kind = 'lecture',
  int? lectureNumber,
  int? examYear,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'description': '',
  'university': ref(1, 'جامعة دمشق'),
  'faculty': ref(10, 'كلية الهندسة المعلوماتية'),
  'level': ref(100, 'السنة الأولى'),
  'course': ref(1000, 'برمجة 1'),
  'instructor': {'id': 50, 'full_name': 'سامر الخطيب', 'title': 'د.'},
  'lecture_number': lectureNumber,
  'category': kind == 'lecture' ? ref(7, 'نظري') : null,
  'exam_year': examYear,
  'exam_type': kind == 'exam' ? ref(8, 'الدورة الأولى') : null,
  'semester': kind == 'exam' ? ref(9, 'الفصل الأول') : null,
  'published_at': '2026-09-20T10:00:00Z',
  'file': {
    'id': 'f-$id',
    'version': 1,
    'extension': 'pdf',
    'mime_type': 'application/pdf',
    'size_bytes': 48213,
    'page_count': 4,
    'uploaded_at': '2026-09-20T10:00:00Z',
  },
  'file_endpoint': '/api/v1/catalog/contents/$id/file/',
  'is_favorite': false,
  'watermark_text': 'UL-ABCDEF1234',
};

/// Routes every signed-in shell touches (notification badge).
void stubShell(StubBackend b) {
  b
    ..json('GET', '/me/notifications/', page(const []))
    ..json('GET', '/me/notifications/unread-count/', {'unread': 0});
}
