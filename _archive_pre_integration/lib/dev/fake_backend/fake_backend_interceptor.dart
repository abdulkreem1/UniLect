import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_backend.dart';
import 'fake_http.dart';

/// DEV ONLY — answers every request from [FakeBackend] instead of the network.
/// Registered as the last interceptor so auth/device headers are already set,
/// exactly as a real server would receive them.
class FakeBackendInterceptor extends Interceptor {
  FakeBackendInterceptor(
    this.backend, {
    this.latency = const Duration(milliseconds: 350),
  });

  final FakeBackend backend;
  final Duration latency;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final request = await _toFakeRequest(options);
    if (latency > Duration.zero) {
      await _simulateTransfer(options);
    }
    final response = await backend.handle(request);
    final dioResponse = Response<dynamic>(
      requestOptions: options,
      statusCode: response.status,
      data: response.body,
    );
    if (response.status >= 400) {
      handler.reject(
        DioException.badResponse(
          statusCode: response.status,
          requestOptions: options,
          response: dioResponse,
        ),
        true,
      );
    } else {
      handler.resolve(dioResponse);
    }
  }

  Future<void> _simulateTransfer(RequestOptions options) async {
    final progress = options.onSendProgress;
    if (progress == null) return Future.delayed(latency);
    const steps = 8;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(latency ~/ 2);
      progress(i, steps);
    }
  }

  static Future<FakeRequest> _toFakeRequest(RequestOptions o) async {
    final headers = {
      for (final e in o.headers.entries)
        e.key.toLowerCase(): e.value.toString(),
    };
    final query = {
      for (final e in o.queryParameters.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    final data = o.data;
    if (data is FormData) {
      FakeUpload? upload;
      for (final f in data.files) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in f.value.finalize()) {
          builder.add(chunk);
        }
        upload = FakeUpload(
          name: f.value.filename ?? 'file',
          bytes: builder.toBytes(),
        );
      }
      return FakeRequest(
        method: o.method.toUpperCase(),
        path: o.path,
        query: query,
        headers: headers,
        fields: {for (final e in data.fields) e.key: e.value},
        file: upload,
      );
    }
    return FakeRequest(
      method: o.method.toUpperCase(),
      path: o.path,
      query: query,
      headers: headers,
      json: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }
}
