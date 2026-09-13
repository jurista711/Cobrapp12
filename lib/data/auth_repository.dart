import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';

class AuthRepository {
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

  Future<bool> signInWithGoogle() => supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : 'cobrapp://login-callback/',
      );

  Future<bool> signInWithApple() => supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? Uri.base.origin : 'cobrapp://login-callback/',
      );

  bool get hasPremiumAccess {
    final user = currentUser;
    if (user == null) return false;
    final userPremium = user.userMetadata?['premium'];
    final appPremium = user.appMetadata['premium'];
    return userPremium == true || appPremium == true;
  }

  Future<void> signOut() => supabase.auth.signOut();
}
