import '../datasources/remote/firestore_refs.dart';
import '../../domain/entities/member_entity.dart';

class MemberRepository {
  final FirestoreRefs _refs;
  MemberRepository(this._refs);

  Future<MemberEntity?> findByEmail(String email) async {
    final doc = await _refs.members.doc(email.toLowerCase()).get();
    if (!doc.exists) return null;
    return MemberEntity.fromMap(doc.id, doc.data()!);
  }

  Future<void> upsert(MemberEntity member) =>
      _refs.members.doc(member.id).set(member.toMap());

  Future<void> linkUid(String id, String uid) =>
      _refs.members.doc(id).update({'uid': uid});

  Stream<List<MemberEntity>> watchAll() =>
      _refs.members.orderBy('displayName').snapshots().map((snap) =>
          snap.docs.map((d) => MemberEntity.fromMap(d.id, d.data())).toList());
}
