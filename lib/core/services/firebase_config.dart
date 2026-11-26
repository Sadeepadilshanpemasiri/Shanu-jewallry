import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static const local = kDebugMode && bool.fromEnvironment('LOCAL_FIREBASE');
  static const _options = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  static Future<void> initialize() async {
    if (local) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-jewellery-local-key',
          appId: '1:100000000000:web:1111111111111111111111',
          messagingSenderId: '100000000000',
          projectId: 'demo-jewellery-manager',
          storageBucket: 'demo-jewellery-manager.appspot.com',
        ),
      );
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
      return;
    }
    if ([
      _options.apiKey,
      _options.appId,
      _options.projectId,
      _options.messagingSenderId,
      _options.authDomain ?? '',
      _options.storageBucket ?? '',
    ].any((value) => value.isEmpty)) {
      throw const FirebaseSetupException();
    }
    await Firebase.initializeApp(options: _options);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }
}

class FirebaseSetupException implements Exception {
  const FirebaseSetupException();
}
