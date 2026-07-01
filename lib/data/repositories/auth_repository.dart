import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/member_entity.dart';
import 'member_repository.dart';

abstract class GoogleAuthenticator {
  Future<String?> signInAndGetEmail();
}

class FirebaseGoogleAuthenticator implements GoogleAuthenticator {
  final FirebaseAuth _auth;
  FirebaseGoogleAuthenticator(this._auth);

  @override
  Future<String?> signInAndGetEmail() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return cred.user?.email;
  }
}

class AuthRepository {
  final FirebaseAuth _auth;
  final MemberRepository _members;
  final GoogleAuthenticator _google;

  AuthRepository(this._auth, this._members, this._google);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Resolves the whitelisted member for the currently signed-in Firebase user,
  /// used to restore a session on app launch. Returns null if there is no
  /// signed-in user, or the user's email is not an active member.
  Future<MemberEntity?> resolveCurrentMember() async {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    final member = await _members.findByEmail(email);
    if (member == null || !member.active) return null;
    return member;
  }

  Future<MemberEntity?> signInWithGoogle() async {
    final email = await _google.signInAndGetEmail();
    if (email == null) return null;
    final member = await _members.findByEmail(email);
    if (member == null || !member.active) {
      await _auth.signOut();
      return null;
    }
    if (member.uid == null && _auth.currentUser != null) {
      await _members.linkUid(member.id, _auth.currentUser!.uid);
    }
    return member;
  }

  Future<void> signOut() => _auth.signOut();
}
