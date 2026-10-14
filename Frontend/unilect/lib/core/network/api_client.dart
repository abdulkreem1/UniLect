import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/json.dart';
import 'app_failure.dart';
import 'error_mapper.dart';

/// A file to send in a multipart request. Bytes are read lazily so large files
/// are only loaded when the upload actually starts.
class UploadFile {
  const UploadFile({
    required this.name,
    required this.sizeBytes,
    required this.readBytes,
  });

  final String name;
  final int sizeBytes;
  final Future<Uint8List> Function() readBytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// A protected file held in memory, plus the viewer watermark the server
/// sends with it (`X-Watermark-Text`).
class FileBytes {
  const FileBytes({required this.bytes, this.watermark});

  final Uint8List bytes;
  final String? watermark;
}

typedef JsonMap = Map<String, dynamic>;

/// The single entry point for HTTP. Feature repositories depend on this and
/// never on Dio directly. All failures are thrown as [AppFailure].
///
/// Paths are relative to the versioned base URL and end with `/`, as the API
/// requires (e.g. `/catalog/courses/`).
class ApiClient {
  ApiClient(this._dio);

  /// Largest page the API serves (`max_page_size`).
  static const maxPageSize = 100;

  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) => _send<T>(
    () => _dio.get<T>(
      path,
      queryParameters: _clean(query),
      options: _options(authenticated),
    ),
  );

  /// One page of a paginated list.
  Future<Paged<T>> getPage<T>(
    String path,
    T Function(Json json) fromJson, {
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? query,
  }) async {
    final json = await get<JsonMap>(
      path,
      query: {...?query, 'page': page, 'page_size': pageSize},
    );
    return Paged.fromDrf(json, fromJson, page: page, pageSize: pageSize);
  }

  /// Every item of a paginated list (catalog lookups, small admin lists).
  Future<List<T>> getAll<T>(
    String path,
    T Function(Json json) fromJson, {
    Map<String, dynamic>? query,
  }) async {
    final items = <T>[];
    for (var page = 1; ; page++) {
      final json = await get<JsonMap>(
        path,
        query: {...?query, 'page': page, 'page_size': maxPageSize},
      );
      items.addAll(parseList(json['results'], fromJson));
      if (json['next'] == null) return items;
    }
  }

  /// A non-paginated list endpoint.
  Future<List<T>> getList<T>(
    String path,
    T Function(Json json) fromJson, {
    Map<String, dynamic>? query,
  }) async => parseList(await get<List<dynamic>>(path, query: query), fromJson);

  Future<T> post<T>(
    String path, {
    Object? body,
    bool authenticated = true,
    Map<String, String>? headers,
  }) => _send<T>(
    () => _dio.post<T>(
      path,
      data: body,
      options: _options(authenticated, headers: headers),
    ),
  );

  Future<T> patch<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.patch<T>(path, data: body));

  Future<void> delete(String path) =>
      _send<void>(() => _dio.delete<void>(path));

  /// Downloads a protected file into memory only (FR-055: nothing is written
  /// to disk).
  Future<FileBytes> getFile(String path, {CancelToken? cancelToken}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Cache-Control': 'no-store'},
        ),
      );
      final data = response.data ?? const <int>[];
      return FileBytes(
        bytes: data is Uint8List ? data : Uint8List.fromList(data),
        watermark: response.headers.value('x-watermark-text'),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Multipart POST. Null fields are omitted; [file] is sent as `file`.
  Future<JsonMap> postMultipart(
    String path, {
    UploadFile? file,
    Map<String, Object?> fields = const {},
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = await file?.readBytes();
    final form = FormData.fromMap({
      for (final e in fields.entries)
        if (e.value != null) e.key: e.value.toString(),
      if (file != null && bytes != null)
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    return _send<JsonMap>(
      () => _dio.post<JsonMap>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      ),
    );
  }

  Future<T> _send<T>(Future<Response<T>> Function() call) async {
    try {
      final response = await call();
      return response.data as T;
    } on DioException catch (e) {
      throw mapDioException(e);
    } on AppFailure {
      rethrow;
    } on Object catch (e) {
      throw UnknownFailure(e);
    }
  }

  static Options? _options(
    bool authenticated, {
    Map<String, String>? headers,
  }) => authenticated && headers == null
      ? null
      : Options(
          headers: headers,
          extra: {if (!authenticated) RequestFlags.skipAuth: true},
        );

  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final e in query.entries)
        if (e.value != null && e.value.toString().isNotEmpty) e.key: e.value,
    };
  }
}

abstract final class RequestFlags {
  static const skipAuth = 'skipAuth';
  static const retried = 'retried';
}
