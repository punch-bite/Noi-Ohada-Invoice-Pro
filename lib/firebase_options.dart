// lib/firebase_options.dart
//
// 🔥 Configuration Firebase par plateforme (générée selon le modèle FlutterFire).
// Ces valeurs sont PUBLIQUES (config client Firebase) — elles ne sont pas des secrets.
// Les secrets (ENKAP, SMTP…) sont injectés au build via --dart-define.
//
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvSY8rOv-VyLycD2DZjeB7BM4CmDKsfZQ',
    appId: '1:942740787802:android:8051a7fc714414a6683e63',
    messagingSenderId: '942740787802',
    projectId: 'facture-ohada',
    authDomain: 'facture-ohada.firebaseapp.com',
    storageBucket: 'facture-ohada.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDvSY8rOv-VyLycD2DZjeB7BM4CmDKsfZQ',
    appId: '1:942740787802:ios:8051a7fc714414a6683e63',
    messagingSenderId: '942740787802',
    projectId: 'facture-ohada',
    authDomain: 'facture-ohada.firebaseapp.com',
    storageBucket: 'facture-ohada.appspot.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvSY8rOv-VyLycD2DZjeB7BM4CmDKsfZQ',
    appId: '1:942740787802:web:8051a7fc714414a6683e63',
    messagingSenderId: '942740787802',
    projectId: 'facture-ohada',
    authDomain: 'facture-ohada.firebaseapp.com',
    storageBucket: 'facture-ohada.appspot.com',
  );
}
