import 'package:uuid/uuid.dart';
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

  Stream<CycleEntity?> watchOpenCycle() =>
      _refs.cycles.where('status', isEqualTo: 'open').limit(1).snapshots().map(
          (snap) => snap.docs.isEmpty
              ? null
              : CycleEntity.fromMap(snap.docs.first.id, snap.docs.first.data()));

  /// Returns the current open cycle, creating one if none exists.
  Future<CycleEntity> ensureOpenCycle(DateTime now) async {
    final existing = await getOpenCycle();
    if (existing != null) return existing;
    final cycle = CycleEntity(
      id: const Uuid().v4(),
      status: CycleStatus.open,
      openedAt: now,
      completedAt: null,
    );
    await _refs.cycles.doc(cycle.id).set(cycle.toMap());
    return cycle;
  }

  Future<void> completeCycle(String cycleId, DateTime now) =>
      _refs.cycles.doc(cycleId).update({
        'status': CycleStatus.completed.name,
        'completedAt': now.toUtc().toIso8601String(),
      });

  Stream<List<CycleEntity>> watchCompleted() => _refs.cycles
      .where('status', isEqualTo: 'completed')
      .snapshots()
      .map((snap) => (snap.docs
          .map((d) => CycleEntity.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.completedAt ?? b.openedAt)
            .compareTo(a.completedAt ?? a.openedAt))));
}
