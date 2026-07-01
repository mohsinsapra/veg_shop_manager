import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veg_shop_manager/data/datasources/remote/firestore_refs.dart';
import 'package:veg_shop_manager/data/repositories/member_repository.dart';
import 'package:veg_shop_manager/domain/entities/member_entity.dart';
import 'package:veg_shop_manager/presentation/providers/firebase_providers.dart';
import 'package:veg_shop_manager/presentation/pages/admin/members_management_page.dart';

void main() {
  testWidgets('MembersManagementPage lists members', (tester) async {
    final fake = FakeFirebaseFirestore();
    await MemberRepository(FirestoreRefs(fake)).upsert(const MemberEntity(
        id: 'ana@x.com', email: 'ana@x.com', displayName: 'Ana',
        role: MemberRole.member, shopIds: ['s1'], active: true, uid: null));
    await tester.pumpWidget(ProviderScope(
      overrides: [firebaseFirestoreProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: Scaffold(body: MembersManagementPage())),
    ));
    await tester.pump();
    expect(find.text('Ana'), findsOneWidget);
  });
}
