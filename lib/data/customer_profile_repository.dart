import 'cobrapp_repository.dart';

/// Etapa 16: campos adicionais de cliente mapeados da planilha clientes.xlsx.
extension CustomerProfileRepository on CobrAppRepository {
  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> _cleanTags(List<String>? values) {
    if (values == null) return const [];
    return values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
  }

  Future<void> addCustomerExpanded({
    required String name,
    String? lastName,
    String? document,
    String? address,
    String? landline,
    String? phone,
    String? email,
    List<String>? tags,
    String? notes,
    String? coDebtorName,
    String? coDebtorDocument,
    String? coDebtorPhone,
    bool isActive = true,
    String? reference1Name,
    String? reference1Relation,
    String? reference1Phone,
  }) async {
    await db.from('cobrapp_customers').insert({
      'user_id': uid,
      'name': name.trim(),
      'last_name': _clean(lastName),
      'document': _clean(document),
      'address': _clean(address),
      'landline': _clean(landline),
      'phone': _clean(phone),
      'email': _clean(email),
      'tags': _cleanTags(tags),
      'notes': _clean(notes),
      'co_debtor_name': _clean(coDebtorName),
      'co_debtor_document': _clean(coDebtorDocument),
      'co_debtor_phone': _clean(coDebtorPhone),
      'is_active': isActive,
      'reference1_name': _clean(reference1Name),
      'reference1_relation': _clean(reference1Relation),
      'reference1_phone': _clean(reference1Phone),
    });
  }

  Future<void> updateCustomerExpanded({
    required String id,
    required String name,
    String? lastName,
    String? document,
    String? address,
    String? landline,
    String? phone,
    String? email,
    List<String>? tags,
    String? notes,
    String? coDebtorName,
    String? coDebtorDocument,
    String? coDebtorPhone,
    bool isActive = true,
    String? reference1Name,
    String? reference1Relation,
    String? reference1Phone,
  }) async {
    await db.from('cobrapp_customers').update({
      'name': name.trim(),
      'last_name': _clean(lastName),
      'document': _clean(document),
      'address': _clean(address),
      'landline': _clean(landline),
      'phone': _clean(phone),
      'email': _clean(email),
      'tags': _cleanTags(tags),
      'notes': _clean(notes),
      'co_debtor_name': _clean(coDebtorName),
      'co_debtor_document': _clean(coDebtorDocument),
      'co_debtor_phone': _clean(coDebtorPhone),
      'is_active': isActive,
      'reference1_name': _clean(reference1Name),
      'reference1_relation': _clean(reference1Relation),
      'reference1_phone': _clean(reference1Phone),
    }).eq('id', id).eq('user_id', uid);
  }
}
