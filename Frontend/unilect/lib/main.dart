import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    ProviderScope(
      // Failures are surfaced to the user with an explicit retry instead of
      // silent automatic retries.
      retry: (_, _) => null,
      child: const UniLectApp(),
    ),
  );
}
