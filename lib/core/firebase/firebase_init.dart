import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // On web, the streaming WebChannel transport can be buffered/blocked by
  // proxies and some browser environments, which makes reads hang forever.
  // Force long-polling on web so reads use discrete requests instead. Keep
  // IndexedDB persistence off on web (legacy, can also hang) and on for mobile.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: !kIsWeb,
    webExperimentalForceLongPolling: kIsWeb,
  );
}
