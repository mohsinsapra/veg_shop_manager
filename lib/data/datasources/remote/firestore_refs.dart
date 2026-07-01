import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRefs {
  final FirebaseFirestore db;
  FirestoreRefs(this.db);

  CollectionReference<Map<String, dynamic>> get shops => db.collection('shops');
  CollectionReference<Map<String, dynamic>> get catalogItems => db.collection('catalogItems');
  CollectionReference<Map<String, dynamic>> get members => db.collection('members');
  CollectionReference<Map<String, dynamic>> get cycles => db.collection('cycles');
  CollectionReference<Map<String, dynamic>> get entries => db.collection('entries');
}
