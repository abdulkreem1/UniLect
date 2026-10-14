import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_store.dart';

/// Identity of this app installation, used to bind a student account to one
/// device (FR-008). The install ID is a random UUID kept in secure storage:
/// it contains no hardware identifiers and is stable until the app's secure
/// storage is wiped (e.g. uninstall on Android).
class DeviceIdentity {
  const DeviceIdentity({
    required this.installId,
    required this.platform,
    required this.model,
  });

  final String installId;
  final String platform;
  final String model;

  /// `device` object of the login request. The install ID must match
  /// `[A-Za-z0-9_-]{16,128}` (a v4 UUID does) and is also sent as the
  /// `X-Device-ID` header on every request.
  Map<String, dynamic> toJson() => {
    'installation_id': installId,
    'platform': platform,
    'model': model.length > 100 ? model.substring(0, 100) : model,
  };
}

abstract interface class DeviceIdentityProvider {
  Future<DeviceIdentity> get();
}

class DeviceIdentityService implements DeviceIdentityProvider {
  DeviceIdentityService(this._store, {DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  static const _key = 'device.installId.v1';
  final SecureStore _store;
  final DeviceInfoPlugin _deviceInfo;
  DeviceIdentity? _cached;

  @override
  Future<DeviceIdentity> get() async {
    final cached = _cached;
    if (cached != null) return cached;
    var id = await _store.read(_key);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await _store.write(_key, id);
    }
    return _cached = DeviceIdentity(
      installId: id,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      model: await _model(),
    );
  }

  Future<String> _model() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return '${info.manufacturer} ${info.model}';
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return info.utsname.machine;
        default:
          return 'unknown';
      }
    } on Object {
      return 'unknown'; // Model is informational only.
    }
  }
}
