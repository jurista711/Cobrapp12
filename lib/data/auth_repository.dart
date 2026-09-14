import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../premium_service.dart';

class AuthRepository {
  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  Stream<AuthState> get authState => supabase.auth.onAuthStateChange;
  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) =>
      supabase.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUp(
    String email,
    String password, {
    required String companyName,
    String? companyDocument,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
  }) =>
      supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'company_name': companyName.trim(),
          'company_document': companyDocument?.trim(),
          'company_address': companyAddress?.trim(),
          'company_phone': companyPhone?.trim(),
          'company_email': companyEmail?.trim(),
        },
      );

  Future<void> resetPassword(String email) =>
      supabase.auth.resetPasswordForEmail(email.trim());

  Future<bool> signInWithGoogle() async {
    if (kIsWeb || googleWebClientId.isEmpty) {
      return supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'cobrapp://login-callback/',
      );
    }

    final googleSignIn = GoogleSignIn(serverClientId: googleWebClientId);
    final account = await googleSignIn.signIn();
    if (account == null) return false;
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google não retornou um token de identidade.');
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    return true;
  }

  Future<bool> signInWithApple() async {
    final isAppleNative = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (!isAppleNative) {
      return supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? Uri.base.origin : 'cobrapp://login-callback/',
      );
    }

    final rawNonce = supabase.auth.generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple não retornou um token de identidade.');
    }
    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
    return true;
  }

  bool get isCollaborator => currentUser?.appMetadata['collaborator'] == true;

  String get effectiveOwnerId {
    final user = currentUser;
    if (user == null) throw StateError('Usuário não autenticado.');
    return user.appMetadata['owner_id']?.toString() ?? user.id;
  }

  String get collaboratorRole =>
      currentUser?.appMetadata['collaborator_role']?.toString() ?? 'owner';

  Map<String, dynamic> get collaboratorPermissions {
    final raw = currentUser?.appMetadata['permissions'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  bool hasAreaAccess(String area) {
    if (!isCollaborator) return true;
    if (collaboratorRole == 'admin') return true;
    final value = collaboratorPermissions[area];
    return value == true;
  }

  bool get hasPremiumAccess {
    final user = currentUser;
    if (user == null) return false;
    final userPremium = user.userMetadata?['premium'];
    final appPremium = user.appMetadata['premium'];
    final plan = (user.userMetadata?['plan'] ?? user.userMetadata?['plano'] ?? '')
        .toString()
        .toLowerCase();
    return PremiumService.runtimePremium ||
        userPremium == true ||
        appPremium == true ||
        plan == 'premium' ||
        plan == 'pro';
  }

  Future<void> signOut() => supabase.auth.signOut();
}
