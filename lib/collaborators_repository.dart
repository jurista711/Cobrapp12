import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';

class CollaboratorsRepository {
  SupabaseClient get db => Supabase.instance.client;
  String get ownerId => AuthRepository().effectiveOwnerId;

  Future<List<Map<String, dynamic>>> all() async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_collaborators')
          .select()
          .eq('owner_id', ownerId)
          .order('name'));

  bool get isPremium => AuthRepository().hasPremiumAccess;

  Future<void> add({
    required String name,
    required String email,
    required String password,
    required String role,
    required Map<String, bool> permissions,
    String? routeName,
    bool active = true,
  }) async {
    final existing = await all();
    if (!isPremium && existing.isNotEmpty) {
      throw StateError('Adicionar mais de um colaborador é uma funcionalidade Premium.');
    }
    await db.rpc('cobrapp_create_collaborator', params: {
      'p_name': name.trim(),
      'p_email': email.trim(),
      'p_password': password,
      'p_role': role,
      'p_permissions': permissions,
      'p_route_name': routeName,
      'p_is_active': active,
    });
  }

  Future<void> update({
    required String id,
    required String name,
    required String email,
    String password = '',
    required String role,
    required Map<String, bool> permissions,
    String? routeName,
    required bool active,
  }) async {
    await db.rpc('cobrapp_update_collaborator', params: {
      'p_id': id,
      'p_name': name.trim(),
      'p_email': email.trim(),
      'p_password': password,
      'p_role': role,
      'p_permissions': permissions,
      'p_route_name': routeName,
      'p_is_active': active,
    });
  }
}
