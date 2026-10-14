import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/client_config.dart';

/// Server settings relevant to the client (upload limits, watermark…).
/// Re-fetched whenever the signed-in user changes.
final clientConfigProvider = FutureProvider<ClientConfig>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(configRepositoryProvider).fetch();
});
