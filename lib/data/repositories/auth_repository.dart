import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/member_entity.dart';
import 'member_repository.dart';

abstract class GoogleAuthenticator {
  /// Performs the platform Google sign-in. Firebase auth state updates as a
  /// result; the returned email is informational (null if cancelled).
  Future<String?> signInAndGetEmail();
}

class FirebaseGoogleAuthenticator implements GoogleAuthenticator {
  final FirebaseAuth _auth;
  FirebaseGoogleAuthenticator(this._auth);

  @override
  Future<String?> signInAndGetEmail() async {
    if (kIsWeb) {
      // On web, use Firebase's hosted popup handler — it runs through the
      // project's pre-authorized auth domain, avoiding OAuth origin_mismatch.
      final cred = await _auth.signInWithPopup(GoogleAuthProvider());
      return cred.user?.email;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
    return _auth.currentUser?.email;
  }
}

class AuthRepository {
  final FirebaseAuth _auth;
  final MemberRepository _members;
  final GoogleAuthenticator _google;

  AuthRepository(this._auth, this._members, this._google);

  /// Fires on every sign-in / sign-out / session-restore. This is the single
  /// source of truth for auth state — the controller listens to it rather than
  /// checking currentUser once (which is null before web restore completes).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Kicks off the Google sign-in flow. The result is delivered via
  /// [authStateChanges], not this future.
  Future<void> beginGoogleSignIn() => _google.signInAndGetEmail();

  /// Resolves the whitelisted, active member for [email]. Returns null if the
  /// email is not an active member. Links the Firebase uid on first resolve.
  Future<MemberEntity?> resolveMember(String? email) async {
    if (email == null) return null;
    final member = await _members.findByEmail(email);
    if (member == null || !member.active) return null;
    if (member.uid == null && _auth.currentUser != null) {
      await _members.linkUid(member.id, _auth.currentUser!.uid);
    }
    return member;
  }

  Future<void> signOut() => _auth.signOut();
}
