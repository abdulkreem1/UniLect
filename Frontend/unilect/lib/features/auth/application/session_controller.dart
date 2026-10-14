import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

sealed class SessionState {
  const SessionState();
}

/// Restoring a stored session at startup.
class SessionLoading extends SessionState {
  const SessionLoading();
}

/// Stored session could not be verified (e.g. offline at startup).
class SessionRestoreFailed extends SessionState {
  const SessionRestoreFailed(this.error);
  final Object error;
}

class SignedOut extends SessionState {
  const SignedOut({this.reasonCode});

  /// Why the user was signed out by the server, if applicable.
  final String? reasonCode;
}

class SignedIn extends SessionState {
  const SignedIn(this.user);
  final AppUser user;
}

class SessionController extends Notifier<SessionState> {
  StreamSubscription<Object>? _terminations;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  SessionState build() {
    _terminations = ref
        .watch(sessionTerminationsProvider)
        .stream
        .listen((event) => state = SignedOut(reasonCode: event.code));
    ref.onDispose(() => _terminations?.cancel());
    unawaited(restore());
    return const SessionLoading();
  }

  Future<void> restore() async {
    state = const SessionLoading();
    if (!await _repo.hasSession()) {
      state = const SignedOut();
      return;
    }
    try {
      state = SignedIn(await _repo.fetchMe());
    } on ApiFailure catch (f) {
      await _repo.clearLocalSession();
      state = SignedOut(reasonCode: f.code);
    } on AppFailure catch (e) {
      state = SessionRestoreFailed(e);
    }
  }

  /// Throws [AppFailure] for invalid credentials etc.; returns
  /// [DeviceBlocked] when the student must request a device change.
  Future<LoginOutcome> login(String email, String password) async {
    final outcome = await _repo.login(email: email, password: password);
    if (outcome is LoggedIn) state = SignedIn(outcome.user);
    return outcome;
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const SignedOut();
  }

  void updateUser(AppUser user) {
    if (state is SignedIn) state = SignedIn(user);
  }

  /// After the mandatory first password change the API lifts the restriction;
  /// the guard then lets the user into their area.
  void passwordChanged() {
    final current = state;
    if (current is SignedIn) {
      state = SignedIn(current.user.copyWith(mustChangePassword: false));
    }
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in user. Only read from screens behind the auth guard.
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(sessionControllerProvider);
  return state is SignedIn ? state.user : null;
});
