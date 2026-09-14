import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_config.dart';
import '../premium_service.dart';

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
