import '../datasources/remote/firestore_refs.dart';
import '../../core/firebase/stream_retry.dart';
import '../../domain/entities/member_entity.dart';

class MemberRepository {
  final FirestoreRefs _refs;
  MemberRepository(this._refs);

  Future<MemberEntity?> findByEmail(String email) async {
    // Guard against a stalled read so the UI surfaces an error instead of
    // hanging on a spinner if the network is unreachable.
    final doc = await _refs.members
        .doc(email.toLowerCase())
        .get()
        .timeout(const Duration(seconds: 15));
    if (!doc.exists) return null;
    return MemberEntity.fromMap(doc.id, doc.data()!);
  }

  Future<void> upsert(MemberEntity member) =>
      _refs.members.doc(member.id.toLowerCase()).set(member.toMap());

  Future<void> setActive(String id, bool active) =>
      _refs.members.doc(id.toLowerCase()).update({'active': active});

  Future<void> linkUid(String id, String uid) =>
      _refs.members.doc(id.toLowerCase()).update({'uid': uid});

  /// Removes the member document — the person loses app access. Their Google
  /// account itself is untouched (Firebase Auth users are managed separately).
  Future<void> delete(String id) =>
      _refs.members.doc(id.toLowerCase()).delete();

  Stream<List<MemberEntity>> watchAll() => retryingSnapshots(
    () => _refs.members
        .orderBy('displayName')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MemberEntity.fromMap(d.id, d.data()))
              .toList(),
        ),
  );
}
