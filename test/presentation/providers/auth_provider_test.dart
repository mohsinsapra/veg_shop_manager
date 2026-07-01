import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/auth_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';

class _FakeGoogle implements GoogleAuthenticator {
  final String? email;
  _FakeGoogle(this.email);
  @override
  Future<String?> signInAndGetEmail() async => email;
}

void main() {
  late MemberRepository members;
  setUp(() {
    members = MemberRepository(FirestoreRefs(FakeFirebaseFirestore()));
  });

  test('signInWithGoogle returns member when email is whitelisted and active', () async {
    await members.upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.admin, shopIds: [], active: true, uid: null));
    final repo = AuthRepository(MockFirebaseAuth(), members, _FakeGoogle('ANA@x.com'));
    final result = await repo.signInWithGoogle();
    expect(result?.isAdmin, true);
  });

  test('signInWithGoogle returns null when email not whitelisted', () async {
    final repo = AuthRepository(MockFirebaseAuth(), members, _FakeGoogle('stranger@x.com'));
    expect(await repo.signInWithGoogle(), isNull);
  });

  test('signInWithGoogle returns null when member inactive', () async {
    await members.upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: false, uid: null));
    final repo = AuthRepository(MockFirebaseAuth(), members, _FakeGoogle('ana@x.com'));
    expect(await repo.signInWithGoogle(), isNull);
  });
}
