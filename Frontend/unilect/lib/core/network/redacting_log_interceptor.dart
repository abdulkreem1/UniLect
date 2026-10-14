import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request log that never prints headers or bodies, so tokens,
/// passwords and reset codes cannot leak into logs (FR-080).
class RedactingLogInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final o = response.requestOptions;
    debugPrint('[api] ${o.method} ${o.path} → ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    debugPrint('[api] ${o.method} ${o.path} ✕ ${err.response?.statusCode}');
    handler.next(err);
  }
}
