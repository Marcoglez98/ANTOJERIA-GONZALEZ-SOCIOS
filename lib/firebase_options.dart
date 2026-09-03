import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase ANTOJERIA GONZALEZ.
/// Android SOCIOS: com.antojeria.gonzalez.socios
class DefaultFirebaseOptions {
  static const _apiKey = 'AIzaSyAs-ltJAqY0J05K15p2a_9GBZFAtZa9ewM';
  static const _appId = '1:183710259601:android:fd1d437a25d38ab383a230';
  static const _messagingSenderId = '183710259601';
  static const _projectId = 'antojeria-gonzalez';

  static bool get isConfigured => true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: 'antojeria-gonzalez.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: 'antojeria-gonzalez.firebasestorage.app',
  );
}
