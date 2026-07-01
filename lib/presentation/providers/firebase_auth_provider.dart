import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/entities/member_entity.dart';
import 'firebase_providers.dart';

enum AuthStatus { unknown, signedOut, noAccess, signedIn }

class AuthSessionState {
  final AuthStatus status;
  final MemberEntity? member;
  final String? error;
  const AuthSessionState(this.status, this.member, {this.error});

  bool get isAdmin => member?.isAdmin ?? false;
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(firestoreRefsProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AuthRepository(
    auth,
    ref.watch(memberRepositoryProvider),
    FirebaseGoogleAuthenticator(auth),
  );
});

class AuthController extends StateNotifier<AuthSessionState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthSessionState(AuthStatus.unknown, null)) {
    _restore();
  }

  /// On launch, restore any persisted Firebase session and re-resolve the
  /// member so a signed-in user stays signed in across restarts.
  Future<void> _restore() async {
    try {
      if (_repo.currentUser == null) {
        state = const AuthSessionState(AuthStatus.signedOut, null);
        return;
      }
      final member = await _repo.resolveCurrentMember();
      if (member == null) {
        await _repo.signOut();
        state = const AuthSessionState(AuthStatus.noAccess, null);
      } else {
        state = AuthSessionState(AuthStatus.signedIn, member);
      }
    } catch (_) {
      state = const AuthSessionState(AuthStatus.signedOut, null);
    }
  }

  Future<void> signIn() async {
    try {
      final member = await _repo.signInWithGoogle();
      if (member == null) {
        state = const AuthSessionState(AuthStatus.noAccess, null);
      } else {
        state = AuthSessionState(AuthStatus.signedIn, member);
      }
    } catch (e) {
      state = AuthSessionState(AuthStatus.signedOut, null, error: 'Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthSessionState(AuthStatus.signedOut, null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSessionState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
