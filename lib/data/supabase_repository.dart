import '../core/supabase_config.dart';

/// Camada única para a aplicação. A UI não conversa diretamente com o Data API.
class SupabaseRepository {
  Future<List<Map<String, dynamic>>> list(String table, {String? orderBy}) async {
    dynamic query = supabase.from(table).select();
    if (orderBy != null) query = query.order(orderBy);
    final result = await query;
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data) async {
    final result = await supabase.from(table).insert(data).select().single();
    return Map<String, dynamic>.from(result);
  }

  Future<Map<String, dynamic>> update(String table, String id, Map<String, dynamic> data) async {
    final result = await supabase.from(table).update(data).eq('id', id).select().single();
    return Map<String, dynamic>.from(result);
  }

  Future<void> delete(String table, String id) async {
    await supabase.from(table).delete().eq('id', id);
  }
}
