import 'dart:typed_data';

/// Transport-agnostic request/response used by the dev fake backend.
class FakeRequest {
  FakeRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    this.json = const {},
    this.fields = const {},
    this.file,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Map<String, dynamic> json;

  /// Multipart text fields.
  final Map<String, String> fields;
  final FakeUpload? file;

  /// Path parameters filled by the router.
  Map<String, String> params = const {};

  String? header(String name) => headers[name.toLowerCase()];

  String param(String name) => params[name]!;

  String? q(String name) {
    final v = query[name];
    return (v == null || v.isEmpty) ? null : v;
  }

  int page() => int.tryParse(query['page'] ?? '') ?? 1;
  int pageSize([int fallback = 20]) =>
      (int.tryParse(query['pageSize'] ?? '') ?? fallback).clamp(1, 100);

  /// Body value from JSON or multipart fields.
  Object? body(String key) => json.containsKey(key) ? json[key] : fields[key];

  String? bodyString(String key) {
    final v = body(key);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int? bodyInt(String key) {
    final v = body(key);
    if (v is int) return v;
    return v == null ? null : int.tryParse(v.toString());
  }
}

class FakeUpload {
  const FakeUpload({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class FakeResponse {
  const FakeResponse(this.status, [this.body]);
  final int status;
  final Object? body;
}

/// Thrown by handlers; rendered as the contract's error envelope.
class FakeError implements Exception {
  const FakeError(
    this.status,
    this.code,
    this.message, {
    this.fields,
    this.details,
  });

  final int status;
  final String code;
  final String message;
  final Map<String, String>? fields;
  final Map<String, dynamic>? details;

  FakeResponse toResponse() => FakeResponse(status, {
    'error': {
      'code': code,
      'message': message,
      if (fields != null) 'fields': fields,
      if (details != null) 'details': details,
    },
  });
}

typedef FakeHandler = Future<FakeResponse> Function(FakeRequest req);

/// Minimal path router supporting `:param` segments.
class FakeRouter {
  final _routes = <(String, List<String>, FakeHandler)>[];

  void on(String method, String pattern, FakeHandler handler) =>
      _routes.add((method, _split(pattern), handler));

  Future<FakeResponse> dispatch(FakeRequest req) {
    final segments = _split(req.path);
    for (final (method, pattern, handler) in _routes) {
      if (method != req.method || pattern.length != segments.length) continue;
      final params = <String, String>{};
      var ok = true;
      for (var i = 0; i < pattern.length; i++) {
        if (pattern[i].startsWith(':')) {
          params[pattern[i].substring(1)] = Uri.decodeComponent(segments[i]);
        } else if (pattern[i] != segments[i]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        req.params = params;
        return handler(req);
      }
    }
    throw const FakeError(404, 'NOT_FOUND', 'Endpoint not found');
  }

  static List<String> _split(String p) =>
      p.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
}
