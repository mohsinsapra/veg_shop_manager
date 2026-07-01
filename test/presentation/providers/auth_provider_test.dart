import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/auth_repository.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';

class _FakeGoogle implements GoogleAuthenticator {
  @override
  Future<String?> signInAndGetEmail() async => null;
}

void main() {
  late MemberRepository members;
  late AuthRepository repo;
  setUp(() {
    members = MemberRepository(FirestoreRefs(FakeFirebaseFirestore()));
    repo = AuthRepository(MockFirebaseAuth(), members, _FakeGoogle());
  });

  test('resolveMember returns member when email is whitelisted and active', () async {
    await members.upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.admin, shopIds: [], active: true, uid: null));
    final result = await repo.resolveMember('ANA@x.com');
    expect(result?.isAdmin, true);
  });

  test('resolveMember returns null when email not whitelisted', () async {
    expect(await repo.resolveMember('stranger@x.com'), isNull);
  });

  test('resolveMember returns null when member inactive', () async {
    await members.upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: false, uid: null));
    expect(await repo.resolveMember('ana@x.com'), isNull);
  });

  test('resolveMember returns null for null email', () async {
    expect(await repo.resolveMember(null), isNull);
  });
}
