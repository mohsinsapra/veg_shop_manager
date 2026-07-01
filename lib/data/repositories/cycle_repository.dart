import '../datasources/remote/firestore_refs.dart';
import '../../domain/entities/cycle_entity.dart';

class CycleRepository {
  final FirestoreRefs _refs;
  CycleRepository(this._refs);

  Future<CycleEntity?> getOpenCycle() async {
    final snap =
        await _refs.cycles.where('status', isEqualTo: 'open').limit(1).get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return CycleEntity.fromMap(d.id, d.data());
  }
}
