import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';

class RoutesRepository {
  SupabaseClient get db => Supabase.instance.client;
  String get ownerId => AuthRepository().effectiveOwnerId;

  Future<List<Map<String, dynamic>>> routes() async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_routes')
          .select()
          .eq('user_id', ownerId)
          .order('name'));

  Future<List<Map<String, dynamic>>> collaborators() async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_collaborators')
          .select('id,name,email,is_active,route_name')
          .eq('owner_id', ownerId)
          .eq('is_active', true)
          .order('name'));

  Future<List<Map<String, dynamic>>> customers() async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_customers')
          .select('id,name,document,phone,is_active,route_id,tags')
          .eq('user_id', ownerId)
          .order('name'));

  Future<String> saveRoute({
    String? id,
    required String name,
    required String region,
    required List<String> areas,
    String? collaboratorId,
    required List<String> customerIds,
  }) async {
    final payload = <String, dynamic>{
      'user_id': ownerId,
      'name': name.trim(),
      'region': region.trim().isEmpty ? null : region.trim(),
      'areas': areas.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'collaborator_id': collaboratorId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    late String routeId;
    if (id == null) {
      final created = await db.from('cobrapp_routes').insert(payload).select('id').single();
      routeId = created['id'].toString();
    } else {
      routeId = id;
      await db.from('cobrapp_routes').update(payload).eq('id', id).eq('user_id', ownerId);
    }

    await db
        .from('cobrapp_customers')
        .update({'route_id': null})
        .eq('user_id', ownerId)
        .eq('route_id', routeId);

    if (customerIds.isNotEmpty) {
      await db
          .from('cobrapp_customers')
          .update({'route_id': routeId})
          .eq('user_id', ownerId)
          .inFilter('id', customerIds);
    }

    if (collaboratorId != null && collaboratorId.isNotEmpty) {
      await db
          .from('cobrapp_collaborators')
          .update({'route_name': name.trim(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', collaboratorId)
          .eq('owner_id', ownerId);
    }

    return routeId;
  }

  Future<List<Map<String, dynamic>>> customersByRoute(String routeId) async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_customers')
          .select('id,name,document,phone,is_active')
          .eq('user_id', ownerId)
          .eq('route_id', routeId)
          .order('name'));

  Future<List<Map<String, dynamic>>> tags() async =>
      List<Map<String, dynamic>>.from(await db
          .from('cobrapp_tags')
          .select()
          .eq('user_id', ownerId)
          .order('name'));

  Future<List<Map<String, dynamic>>> customerTagLinks() async {
    final customerRows = await customers();
    final ids = customerRows.map((e) => e['id'].toString()).toList();
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(await db
        .from('cobrapp_customer_tags')
        .select('customer_id,tag_id')
        .inFilter('customer_id', ids));
  }

  Future<void> createTag({required String name, required String color}) async {
    await db.from('cobrapp_tags').insert({
      'user_id': ownerId,
      'name': name.trim(),
      'color': color.trim(),
    });
  }

  Future<void> updateTag({required String id, required String name, required String color}) async {
    final linked = List<Map<String, dynamic>>.from(await db
        .from('cobrapp_customer_tags')
        .select('customer_id')
        .eq('tag_id', id));
    await db.from('cobrapp_tags').update({
      'name': name.trim(),
      'color': color.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', ownerId);
    for (final row in linked) {
      await _syncCustomerTags(row['customer_id'].toString());
    }
  }

  Future<void> deleteTag(String id) async {
    final linked = List<Map<String, dynamic>>.from(await db
        .from('cobrapp_customer_tags')
        .select('customer_id')
        .eq('tag_id', id));
    await db.from('cobrapp_tags').delete().eq('id', id).eq('user_id', ownerId);
    for (final row in linked) {
      await _syncCustomerTags(row['customer_id'].toString());
    }
  }

  Future<void> assignTags({required String customerId, required List<String> tagIds}) async {
    await db.from('cobrapp_customer_tags').delete().eq('customer_id', customerId);
    if (tagIds.isNotEmpty) {
      await db.from('cobrapp_customer_tags').insert(
            tagIds.map((tagId) => {'customer_id': customerId, 'tag_id': tagId}).toList(),
          );
    }
    await _syncCustomerTags(customerId);
  }

  Future<void> _syncCustomerTags(String customerId) async {
    final links = List<Map<String, dynamic>>.from(await db
        .from('cobrapp_customer_tags')
        .select('tag_id')
        .eq('customer_id', customerId));
    final tagIds = links.map((e) => e['tag_id'].toString()).toList();
    List<String> names = [];
    if (tagIds.isNotEmpty) {
      final rows = List<Map<String, dynamic>>.from(await db
          .from('cobrapp_tags')
          .select('name')
          .eq('user_id', ownerId)
          .inFilter('id', tagIds));
      names = rows.map((e) => e['name'].toString()).toList()..sort();
    }
    await db
        .from('cobrapp_customers')
        .update({'tags': names})
        .eq('id', customerId)
        .eq('user_id', ownerId);
  }
}
