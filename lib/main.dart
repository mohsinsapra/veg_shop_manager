import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/firebase/firebase_init.dart';
import 'core/storage/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initFirebase();

  final storageService = StorageServiceFactory.instance;
  await storageService.init();

  runApp(const ProviderScope(child: VegShopApp()));
}
