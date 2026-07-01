import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
  late final StreamSubscription<User?> _sub;

  AuthController(this._repo)
      : super(const AuthSessionState(AuthStatus.unknown, null)) {
    // Drive all state from the auth stream: it fires on sign-in, sign-out, and
    // when a persisted web session is restored (which happens asynchronously
    // after startup, so a one-shot currentUser check would miss it).
    _sub = _repo.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      state = const AuthSessionState(AuthStatus.signedOut, null);
      return;
    }
    try {
      final member = await _repo.resolveMember(user.email);
      if (member == null) {
        // Signed into Google but not a whitelisted member. Stay Firebase-authed
        // (rules block all data) and show the no-access screen.
        state = const AuthSessionState(AuthStatus.noAccess, null);
      } else {
        state = AuthSessionState(AuthStatus.signedIn, member);
      }
    } catch (e) {
      state = AuthSessionState(AuthStatus.signedOut, null,
          error: 'Could not load your account: $e');
    }
  }

  Future<void> signIn() async {
    try {
      await _repo.beginGoogleSignIn();
    } catch (e) {
      state = AuthSessionState(AuthStatus.signedOut, null,
          error: 'Sign-in failed: $e');
    }
  }

  Future<void> signOut() => _repo.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSessionState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
