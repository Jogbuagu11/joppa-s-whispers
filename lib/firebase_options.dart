// Firebase project settings for each platform, taken from
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist
// (the same values `flutterfire configure` writes). These identify the app
// to Firebase; they are not secrets.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => Platform.isIOS ? ios : android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCaz7AXoM68htMw_VwQYJ7MbOz6RBiHXdY',
    appId: '1:354863651849:android:83068d29974be0d040acd8',
    messagingSenderId: '354863651849',
    projectId: 'whispers-of-joppa',
    storageBucket: 'whispers-of-joppa.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwmao4EZH08q7ranwbWjR_yCRV2hDApmo',
    appId: '1:354863651849:ios:3cd896c9a5c0c57240acd8',
    messagingSenderId: '354863651849',
    projectId: 'whispers-of-joppa',
    storageBucket: 'whispers-of-joppa.firebasestorage.app',
    iosBundleId: 'com.whispersofjoppa.game',
  );
}
