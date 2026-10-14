import 'dart:convert';

import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Converts a [DioException] into a typed [AppFailure] using the API's error
/// envelope: `{"error": {"code", "message", "details"}}`.
AppFailure mapDioException(DioException e) {
  final inner = e.error;
  if (inner is AppFailure) return inner;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const UnknownFailure('cancelled');
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }
  final response = e.response;
  if (response == null) return UnknownFailure(e.error ?? e.message);
  return failureFromResponse(response.statusCode ?? 0, response.data);
}

ApiFailure failureFromResponse(int status, Object? data) {
  final envelope = _decode(data);
  final error = envelope?['error'];
  if (error is! Map) {
    return ApiFailure(statusCode: status, code: 'http_$status');
  }
  final details = error['details'] is Map
      ? Map<String, dynamic>.from(error['details'] as Map)
      : <String, dynamic>{};
  final fields = <String, String>{
    if (details['fields'] case final Map<dynamic, dynamic> f)
      for (final e in f.entries) e.key.toString(): ?_firstMessage(e.value),
    'non_field_errors': ?_firstMessage(details['non_field_errors']),
  };
  // A validation error's own message is generic ("Invalid input."); the first
  // field message (already localized by the server) tells the user more.
  final message = fields.isNotEmpty
      ? fields.values.first
      : error['message'] as String?;
  return ApiFailure(
    statusCode: status,
    code: (error['code'] as String?) ?? 'http_$status',
    message: message,
    fields: fields,
    details: details,
  );
}

String? _firstMessage(Object? value) => switch (value) {
  final String s => s,
  final List<dynamic> l when l.isNotEmpty => _firstMessage(l.first),
  final Map<dynamic, dynamic> m when m.isNotEmpty => _firstMessage(
    m.values.first,
  ),
  _ => null,
};

Map<String, dynamic>? _decode(Object? data) {
  try {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List<int>) {
      return jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    }
    if (data is String && data.isNotEmpty) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
  } on Object {
    // Not a JSON envelope.
  }
  return null;
}
