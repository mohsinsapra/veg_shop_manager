import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';

void main() {
  test('FirestoreRefs exposes named collections', () {
    final refs = FirestoreRefs(FakeFirebaseFirestore());
    expect(refs.shops.path, 'shops');
    expect(refs.catalogItems.path, 'catalogItems');
    expect(refs.members.path, 'members');
    expect(refs.cycles.path, 'cycles');
    expect(refs.entries.path, 'entries');
  });
}
