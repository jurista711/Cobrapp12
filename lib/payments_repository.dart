import 'dart:math' as math;

import 'data/cobrapp_repository.dart';

extension PaymentsRepository on CobrAppRepository {
  static const List<String> defaultPaymentMethods = [
    'Dinheiro',
    'Pix',
    'Cartão de Crédito',
    'Cartão de Débito',
    'Cheque',
    'Transferência',
  ];

  Future<List<Map<String, dynamic>>> paymentCustomers() async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_customers')
          .select('id,name,document,phone,is_active')
          .eq('user_id', uid)
          .eq('is_active', true)
          .order('name'),
    );
  }

  Future<List<String>> paymentMethods() async {
    final rows = await db
        .from('cobrapp_company_settings')
        .select('payment_methods')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return defaultPaymentMethods;
    final raw = rows.first['payment_methods'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return defaultPaymentMethods;
  }

  Future<List<Map<String, dynamic>>> activeLoansForPayment(String customerId) async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_loans')
          .select('id,customer_id,principal,total_amount,status,default_payment_method,commitment_date,commitment_amount,early_discount_percent')
          .eq('user_id', uid)
          .eq('customer_id', customerId)
          .inFilter('status', ['active', 'overdue'])
          .order('created_at', ascending: false),
    );
  }

  Future<List<Map<String, dynamic>>> openInstallmentsForPayment(String loanId) async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_installments')
          .select('id,loan_id,customer_id,number,due_date,amount,paid_amount,status,late_interest_paid,late_fee_paid')
          .eq('user_id', uid)
          .eq('loan_id', loanId)
          .neq('status', 'paid')
          .neq('status', 'renegotiated')
          .order('due_date'),
    );
  }

  Future<List<Map<String, dynamic>>> paymentHistoryDetailed() async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_payments')
          .select('*, cobrapp_customers(id,name,document), cobrapp_loans(id,principal,status,early_discount_percent), cobrapp_installments(id,number,due_date)')
          .eq('user_id', uid)
          .order('paid_at', ascending: false)
          .order('created_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> registerPayment({
    required String customerId,
    required String loanId,
    required List<String> installmentIds,
    required double amount,
    required String method,
    required DateTime paidAt,
    required bool automatic,
    String? notes,
  }) async {
    final result = await db.rpc(
      'cobrapp_registrar_pagamento_etapa4',
      params: {
        'p_customer_id': customerId,
        'p_loan_id': loanId,
        'p_installment_ids': installmentIds,
        'p_amount': amount,
        'p_method': method,
        'p_paid_at': paidAt.toIso8601String().substring(0, 10),
        'p_notes': notes,
        'p_auto_apply': automatic,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> accountStatement(String customerId) async {
    final loans = List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_loans')
          .select('id,principal,total_amount,status,created_at,early_discount_percent')
          .eq('user_id', uid)
          .eq('customer_id', customerId)
          .order('created_at'),
    );
    final payments = List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_payments')
          .select('id,loan_id,installment_id,amount,paid_at,method,notes,type,principal_amount,interest_amount,late_interest_amount,late_fee_amount,credit_amount,cobrapp_installments(number)')
          .eq('user_id', uid)
          .eq('customer_id', customerId)
          .order('paid_at'),
    );
    final events = <Map<String, dynamic>>[];
    for (final loan in loans) {
      events.add({
        'date': loan['created_at'],
        'kind': 'Empréstimo',
        'description': 'Capital emprestado',
        'amount': (loan['principal'] as num?)?.toDouble() ?? 0,
        'loan_id': loan['id'],
      });
      final discount = (loan['early_discount_percent'] as num?)?.toDouble() ?? 0;
      if (discount > 0) {
        events.add({
          'date': loan['created_at'],
          'kind': 'Desconto',
          'description': 'Desconto de liquidação: ${discount.toStringAsFixed(2)}%',
          'amount': 0.0,
          'loan_id': loan['id'],
        });
      }
    }
    for (final payment in payments) {
      final installment = payment['cobrapp_installments'];
      final number = installment is Map ? installment['number'] : null;
      events.add({
        'date': payment['paid_at'],
        'kind': payment['type'] == 'credit' ? 'Crédito' : 'Pagamento',
        'description': number == null ? (payment['notes'] ?? payment['method'] ?? 'Pagamento') : 'Parcela $number • ${payment['method'] ?? ''}',
        'amount': (payment['amount'] as num?)?.toDouble() ?? 0,
        'principal': (payment['principal_amount'] as num?)?.toDouble() ?? 0,
        'interest': (payment['interest_amount'] as num?)?.toDouble() ?? 0,
        'late_interest': (payment['late_interest_amount'] as num?)?.toDouble() ?? 0,
        'late_fee': (payment['late_fee_amount'] as num?)?.toDouble() ?? 0,
        'credit': (payment['credit_amount'] as num?)?.toDouble() ?? 0,
        'loan_id': payment['loan_id'],
      });
    }
    events.sort((a, b) => (a['date']?.toString() ?? '').compareTo(b['date']?.toString() ?? ''));
    return events;
  }

  Future<double> customerCredit(String customerId) async {
    final rows = await db
        .from('cobrapp_customer_credits')
        .select('balance')
        .eq('user_id', uid)
        .eq('customer_id', customerId)
        .limit(1);
    if (rows.isEmpty) return 0;
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  Future<void> setPromisedPaymentDate({
    required String loanId,
    required DateTime date,
    required double amount,
    String? notes,
  }) async {
    await db
        .from('cobrapp_loans')
        .update({
          'commitment_date': date.toIso8601String().substring(0, 10),
          'commitment_amount': amount,
          'commitment_notes': notes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', loanId)
        .eq('user_id', uid);
  }

  Future<Map<String, dynamic>> createReceipt({
    required String paymentId,
    required String customerId,
    required double amount,
    required String text,
  }) async {
    final inserted = await db
        .from('cobrapp_receipts')
        .insert({
          'user_id': uid,
          'payment_id': paymentId,
          'customer_id': customerId,
          'amount': amount,
          'text_content': text,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(inserted);
  }

  double outstandingAmount(Map<String, dynamic> installment) {
    final amount = (installment['amount'] as num?)?.toDouble() ?? 0;
    final paid = (installment['paid_amount'] as num?)?.toDouble() ?? 0;
    return math.max(0, amount - paid);
  }
}
