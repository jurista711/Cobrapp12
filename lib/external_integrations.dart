import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class ExternalIntegrations {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseStorageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const recaptchaV3SiteKey =
      String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');

  static bool firebaseConfigured = false;
  static bool appCheckConfigured = false;

  static bool get hasFirebaseConfiguration =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static Future<void> initialize() async {
    if (!hasFirebaseConfiguration || firebaseConfigured) return;

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
        authDomain: firebaseAuthDomain.isEmpty ? null : firebaseAuthDomain,
        storageBucket: firebaseStorageBucket.isEmpty ? null : firebaseStorageBucket,
      ),
    );
    firebaseConfigured = true;

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      webProvider: recaptchaV3SiteKey.isEmpty
          ? null
          : ReCaptchaV3Provider(recaptchaV3SiteKey),
    );
    appCheckConfigured = true;
  }
}
