import 'dart:convert';

import 'secure_store.dart';

class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// From a login/refresh response:
  /// `{access, refresh, token_type, access_expires_in, refresh_expires_in}`.
  factory StoredTokens.fromApi(Map<String, dynamic> json, {DateTime? now}) =>
      StoredTokens(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String,
        expiresAt: (now ?? DateTime.now()).add(
          Duration(seconds: json['access_expires_in'] as int? ?? 0),
        ),
      );

  final String accessToken;
  final String refreshToken;

  /// When the access token expires (informational; the server decides).
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
  };

  static StoredTokens? tryParse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StoredTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
    } on Object {
      return null;
    }
  }
}

/// Persists auth tokens in secure storage only, with an in-memory cache so the
/// interceptor does not hit the keystore on every request.
class TokenStorage {
  TokenStorage(this._store);

  static const _key = 'auth.tokens.v1';
  final SecureStore _store;
  StoredTokens? _cache;
  bool _loaded = false;

  Future<StoredTokens?> read() async {
    if (!_loaded) {
      final raw = await _store.read(_key);
      _cache = raw == null ? null : StoredTokens.tryParse(raw);
      _loaded = true;
    }
    return _cache;
  }

  Future<void> save(StoredTokens tokens) async {
    _cache = tokens;
    _loaded = true;
    await _store.write(_key, jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _cache = null;
    _loaded = true;
    await _store.delete(_key);
  }
}
