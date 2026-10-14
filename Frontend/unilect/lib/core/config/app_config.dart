import 'package:flutter/foundation.dart';

/// Build-time configuration supplied through `--dart-define`.
///
/// Nothing secret lives here: the API base URL is public by nature.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment('API_BASE_URL');
    return AppConfig(apiBaseUrl: baseUrl.isEmpty ? _defaultBaseUrl() : baseUrl);
  }

  /// Debug builds talk to the local Django dev server (`manage.py runserver
  /// 0.0.0.0:8000`); the Android emulator reaches the host as 10.0.2.2.
  /// Release builds must pass `API_BASE_URL` explicitly.
  static String _defaultBaseUrl() {
    if (!kDebugMode) return 'https://api.unilect.invalid/api/v1';
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    return 'http://$host:8000/api/v1';
  }

  /// Base URL including the API version, e.g. `https://api.example.com/api/v1`.
  final String apiBaseUrl;

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 60);
}
