import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'data/auth_repository.dart';

class CompanySettingsRepository {
  static const paymentOptions = <String>[
    'Dinheiro',
    'Pix',
    'Cartão de Crédito',
    'Cartão de Débito',
    'Cheque',
    'Transferência',
  ];

  SupabaseClient get db => supabase;
  String get uid => AuthRepository().effectiveOwnerId;

  Future<Map<String, dynamic>> load() async {
    final rows = await db
        .from('cobrapp_company_settings')
        .select()
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) {
      return {
        'user_id': uid,
        'company_name': '',
        'trade_name': '',
        'tax_id': '',
        'address': '',
        'phone': '',
        'email': '',
        'logo_base64': null,
        'signature_base64': null,
        'late_interest_enabled': false,
        'late_interest_rate': 0,
        'late_fee_base': 0,
        'late_fee_type': 'percent',
        'payment_methods': List<String>.from(paymentOptions),
      };
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> save({
    required String companyName,
    required String tradeName,
    required String taxId,
    required String address,
    required String phone,
    required String email,
    String? logoBase64,
    String? signatureBase64,
    required double lateInterestRate,
    required double lateFeeBase,
    required String lateFeeType,
    required List<String> paymentMethods,
  }) async {
    await db.from('cobrapp_company_settings').upsert({
      'user_id': uid,
      'company_name': companyName.trim(),
      'trade_name': tradeName.trim(),
      'tax_id': taxId.trim(),
      'address': address.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'logo_base64': logoBase64,
      'signature_base64': signatureBase64,
      'late_interest_enabled': lateInterestRate > 0,
      'late_interest_rate': lateInterestRate,
      'late_fee_base': lateFeeBase,
      'late_fee_type': lateFeeType,
      'payment_methods': paymentMethods,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
