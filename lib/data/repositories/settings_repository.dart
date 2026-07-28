import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/remote/firestore_refs.dart';
import '../../core/firebase/stream_retry.dart';

class SettingsRepository {
  final FirestoreRefs _refs;
  SettingsRepository(this._refs);

  Stream<bool> watchShowItemImages() => retryingSnapshots(
    () => _refs.appSettings.snapshots().map(
      (snap) => snap.data()?['showItemImages'] as bool? ?? false,
    ),
  );

  Future<void> setShowItemImages(bool v) =>
      _refs.appSettings.set({'showItemImages': v}, SetOptions(merge: true));
}
