import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// FR-058: best-effort capture restriction.
///
/// * Android: sets `FLAG_SECURE` on the activity window — blocks screenshots
///   and hides content from recordings / the recents screen.
/// * iOS: screenshots cannot be blocked by public APIs. The native side
///   reports `UIScreen.isCaptured` (recording, AirPlay, mirroring) so the
///   viewer can hide content while capture is active.
///
/// The UI never claims full protection (see `protectionNote`).
class ScreenProtection {
  ScreenProtection({MethodChannel? channel, EventChannel? captureEvents})
    : _channel = channel ?? const MethodChannel('unilect/screen_protection'),
      _captureEvents =
          captureEvents ?? const EventChannel('unilect/screen_capture');

  final MethodChannel _channel;
  final EventChannel _captureEvents;

  Future<void> enable() => _invoke('enable');

  Future<void> disable() => _invoke('disable');

  /// Emits `true` while the screen is being recorded/mirrored (iOS only).
  Stream<bool> get captureChanges {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const Stream.empty();
    }
    return _captureEvents.receiveBroadcastStream().map((e) => e == true);
  }

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Not available (tests / unsupported platform): protection is optional.
    } on PlatformException catch (e) {
      debugPrint('[screen-protection] $method failed: ${e.code}');
    }
  }
}
