import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// App language: Arabic (default, RTL) or English. The choice is remembered
/// on the device.
class LocaleController extends Notifier<Locale> {
  static const _key = 'app.locale';
  static const supported = [Locale('ar'), Locale('en')];

  @override
  Locale build() {
    unawaited(_restore());
    return supported.first;
  }

  Future<void> _restore() async {
    final saved = await ref.read(secureStoreProvider).read(_key);
    if (saved != null && saved != state.languageCode) {
      state = Locale(saved);
    }
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(secureStoreProvider).write(_key, locale.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
