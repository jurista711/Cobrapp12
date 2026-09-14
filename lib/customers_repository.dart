import 'package:supabase_flutter/supabase_flutter.dart';

class CustomersRepository {
  SupabaseClient get db => Supabase.instance.client;

  String get uid {
    final user = db.auth.currentUser;
    if (user == null) {
      throw StateError('Usuário não autenticado.');
    }
    return user.id;
  }

  Map<String, dynamic> get metadata =>
      Map<String, dynamic>.from(db.auth.currentUser?.userMetadata ?? const {});

  bool get isPremium {
    final plan = (metadata['plan'] ?? metadata['plano'] ?? '').toString().toLowerCase();
    return plan == 'premium' || plan == 'pro';
  }

  int? get configuredFreeLimit {
    final raw = metadata['customer_limit'] ?? metadata['limite_clientes'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  String? clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> cleanTags(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<List<Map<String, dynamic>>> allCustomers() async {
    final rows = await db
        .from('cobrapp_customers')
        .select()
        .eq('user_id', uid)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> customerCount() async {
    final rows = await db
        .from('cobrapp_customers')
        .select('id')
        .eq('user_id', uid);
    return (rows as List).length;
  }

  Future<bool> canAddCustomer() async {
    if (isPremium) return true;
    final limit = configuredFreeLimit;
    if (limit == null || limit <= 0) {
      return true;
    }
    return await customerCount() < limit;
  }

  Future<void> addCustomer(Map<String, dynamic> values) async {
    if (!await canAddCustomer()) {
      throw StateError('Limite de clientes do plano atual atingido.');
    }
    await db.from('cobrapp_customers').insert({
      'user_id': uid,
      ..._customerPayload(values),
    });
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> values) async {
    await db
        .from('cobrapp_customers')
        .update(_customerPayload(values))
        .eq('id', id)
        .eq('user_id', uid);
  }

  Map<String, dynamic> _customerPayload(Map<String, dynamic> values) {
    return {
      'name': (values['name'] ?? '').toString().trim(),
      'last_name': clean(values['last_name']?.toString()),
      'document': clean(values['document']?.toString()),
      'address': clean(values['address']?.toString()),
      'landline': clean(values['landline']?.toString()),
      'phone': clean(values['phone']?.toString()),
      'email': clean(values['email']?.toString()),
      'tags': values['tags'] is List
          ? List<String>.from(values['tags'])
          : cleanTags(values['tags']?.toString()),
      'notes': clean(values['notes']?.toString()),
      'co_debtor_name': clean(values['co_debtor_name']?.toString()),
      'co_debtor_document': clean(values['co_debtor_document']?.toString()),
      'co_debtor_phone': clean(values['co_debtor_phone']?.toString()),
      'is_active': values['is_active'] is bool ? values['is_active'] : true,
      'reference1_name': clean(values['reference1_name']?.toString()),
      'reference1_relation': clean(values['reference1_relation']?.toString()),
      'reference1_phone': clean(values['reference1_phone']?.toString()),
    };
  }

  Future<void> deleteCustomer(String id) async {
    await db
        .from('cobrapp_customers')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> setActive(String id, bool active) async {
    await db
        .from('cobrapp_customers')
        .update({'is_active': active})
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> saveSignature(String id, String? signatureData) async {
    await db
        .from('cobrapp_customers')
        .update({'signature_data': clean(signatureData)})
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<Map<String, int>> customersPerDay() async {
    final rows = await db
        .from('cobrapp_customers')
        .select('created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    final result = <String, int>{};
    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (date == null) continue;
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> customersMostPaid() async {
    final customers = await db
        .from('cobrapp_customers')
        .select('id,name,last_name')
        .eq('user_id', uid);
    final payments = await db
        .from('cobrapp_payments')
        .select('customer_id,amount')
        .eq('user_id', uid);

    final names = <String, String>{};
    for (final raw in customers as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final first = row['name']?.toString() ?? '';
      final last = row['last_name']?.toString() ?? '';
      names[row['id'].toString()] = [first, last]
          .where((e) => e.trim().isNotEmpty)
          .join(' ')
          .trim();
    }

    final totals = <String, double>{};
    for (final raw in payments as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = row['customer_id']?.toString();
      if (id == null || id.isEmpty) continue;
      totals[id] = (totals[id] ?? 0) + ((row['amount'] as num?)?.toDouble() ?? 0);
    }

    final result = [
      for (final entry in totals.entries)
        {
          'customer_id': entry.key,
          'name': names[entry.key] ?? 'Cliente',
          'total_paid': entry.value,
        },
    ];
    result.sort(
      (a, b) => (b['total_paid'] as double).compareTo(a['total_paid'] as double),
    );
    return result;
  }

  Future<int> importCustomers(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;

    final allowed = <Map<String, dynamic>>[];
    final limit = isPremium ? null : configuredFreeLimit;
    var current = limit == null ? 0 : await customerCount();

    for (final item in items) {
      if (limit != null && limit > 0 && current >= limit) {
        break;
      }
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      allowed.add({
        'user_id': uid,
        ..._customerPayload(item),
      });
      current++;
    }

    if (allowed.isEmpty && items.isNotEmpty && limit != null && limit > 0) {
      throw StateError('Limite de clientes do plano atual atingido.');
    }

    if (allowed.isNotEmpty) {
      await db.from('cobrapp_customers').insert(allowed);
    }
    return allowed.length;
  }
}
