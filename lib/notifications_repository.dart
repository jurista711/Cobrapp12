import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';

class NotificationsRepository {
  SupabaseClient get db => Supabase.instance.client;
  AuthRepository get auth => AuthRepository();
  String get ownerId => auth.effectiveOwnerId;
  bool get isPremium => auth.hasPremiumAccess;

  Future<void> sync() async {
    await db.rpc('cobrapp_sync_notifications', params: {'p_user': ownerId});
  }

  Future<void> syncAndSendEmails() async {
    await sync();
    if (!isPremium) return;
    try {
      await db.functions.invoke('cobrapp-send-reminders');
    } catch (_) {
      // A fila permanece no Supabase e será tentada novamente no próximo sync.
    }
  }

  Future<List<Map<String, dynamic>>> all({bool unreadOnly = false}) async {
    var query = db
        .from('cobrapp_notifications')
        .select()
        .eq('user_id', ownerId)
        .isFilter('deleted_at', null);
    if (unreadOnly) query = query.eq('is_read', false);
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> unreadCount() async {
    final rows = await db
        .from('cobrapp_notifications')
        .select('id')
        .eq('user_id', ownerId)
        .eq('is_read', false)
        .isFilter('deleted_at', null);
    return (rows as List).length;
  }

  Future<void> markRead(String id, bool read) async {
    await db
        .from('cobrapp_notifications')
        .update({'is_read': read})
        .eq('id', id)
        .eq('user_id', ownerId);
  }

  Future<void> markAllRead() async {
    await db
        .from('cobrapp_notifications')
        .update({'is_read': true})
        .eq('user_id', ownerId)
        .eq('is_read', false)
        .isFilter('deleted_at', null);
  }

  Future<void> remove(String id) async {
    await db
        .from('cobrapp_notifications')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', ownerId);
  }
}
