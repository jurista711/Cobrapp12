import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class AuthRepository {
  Stream<AuthState> get authState => supabase.auth.onAuthStateChange;
  User? get currentUser => supabase.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) =>
      supabase.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUp(String email, String password) =>
      supabase.auth.signUp(email: email.trim(), password: password);

  Future<void> resetPassword(String email) =>
      supabase.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => supabase.auth.signOut();
}
