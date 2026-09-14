import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/cobrapp_repository.dart';

class LoanSimulation {
  const LoanSimulation({
    required this.total,
    required this.installment,
    required this.totalInterest,
    required this.rows,
  });

  final double total;
  final double installment;
  final double totalInterest;
  final List<LoanScheduleRow> rows;
}

class LoanScheduleRow {
  const LoanScheduleRow({
    required this.number,
    required this.dueDate,
    required this.amount,
    required this.principalPart,
    required this.interestPart,
  });

  final int number;
  final DateTime dueDate;
  final double amount;
  final double principalPart;
  final double interestPart;
}

extension LoansRepository on CobrAppRepository {
  Future<List<Map<String, dynamic>>> loanCustomers() async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_customers')
          .select('id,name,document,phone,is_active')
          .eq('user_id', uid)
          .eq('is_active', true)
          .order('name'),
    );
  }

  Future<Map<String, dynamic>> loanDefaults() async {
    final rows = await db
        .from('cobrapp_company_settings')
        .select('late_interest_enabled,late_interest_rate,late_fee_base')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) {
      return {
        'late_interest_enabled': false,
        'late_interest_rate': 0.0,
        'late_fee_base': 0.0,
      };
    }
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> saveLoanDefaults({
    required bool enabled,
    required double rate,
    required double feeBase,
  }) async {
    await db.from('cobrapp_company_settings').upsert(
      {
        'user_id': uid,
        'late_interest_enabled': enabled,
        'late_interest_rate': rate,
        'late_fee_base': feeBase,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  Future<List<Map<String, dynamic>>> loansDetailed() async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_loans')
          .select(
            '*, cobrapp_customers(id,name,document,phone), cobrapp_installments(id,number,due_date,amount,paid_amount,status,paid_at)',
          )
          .eq('user_id', uid)
          .order('created_at', ascending: false),
    );
  }

  LoanSimulation simulateLoan({
    required double principal,
    required double monthlyRate,
    required int installmentCount,
    required DateTime firstDueDate,
    required String amortizationMethod,
  }) {
    if (principal <= 0 || installmentCount < 1 || monthlyRate < 0) {
      throw ArgumentError('Dados do empréstimo inválidos.');
    }
    final rate = monthlyRate / 100;
    final rows = <LoanScheduleRow>[];
    double installment;
    double total;
    double totalInterest;
    if (amortizationMethod == 'price') {
      installment = rate == 0
          ? principal / installmentCount
          : principal * rate / (1 - math.pow(1 + rate, -installmentCount));
      var balance = principal;
      var sum = 0.0;
      var interestSum = 0.0;
      for (var i = 1; i <= installmentCount; i++) {
        final interestPart = balance * rate;
        var principalPart = installment - interestPart;
        var rowAmount = installment;
        if (i == installmentCount) {
          principalPart = balance;
          rowAmount = principalPart + interestPart;
        }
        balance = math.max(0, balance - principalPart);
        final due = DateTime(firstDueDate.year, firstDueDate.month + i - 1,
            math.min(firstDueDate.day, DateUtilsHelper.daysInMonth(firstDueDate.year, firstDueDate.month + i - 1)));
        rows.add(LoanScheduleRow(number: i, dueDate: due, amount: rowAmount, principalPart: principalPart, interestPart: interestPart));
        sum += rowAmount;
        interestSum += interestPart;
      }
      total = sum;
      totalInterest = interestSum;
    } else {
      totalInterest = principal * rate * installmentCount;
      total = principal + totalInterest;
      installment = total / installmentCount;
      final principalPart = principal / installmentCount;
      final interestPart = totalInterest / installmentCount;
      for (var i = 1; i <= installmentCount; i++) {
        final due = DateTime(firstDueDate.year, firstDueDate.month + i - 1,
            math.min(firstDueDate.day, DateUtilsHelper.daysInMonth(firstDueDate.year, firstDueDate.month + i - 1)));
        rows.add(LoanScheduleRow(number: i, dueDate: due, amount: installment, principalPart: principalPart, interestPart: interestPart));
      }
    }
    return LoanSimulation(
      total: _round2(total),
      installment: _round2(rows.first.amount),
      totalInterest: _round2(totalInterest),
      rows: rows.map((row) => LoanScheduleRow(number: row.number, dueDate: row.dueDate, amount: _round2(row.amount), principalPart: _round2(row.principalPart), interestPart: _round2(row.interestPart))).toList(),
    );
  }

  Future<Map<String, dynamic>> createLoanDetailed({
    required String customerId,
    required double principal,
    required double monthlyRate,
    required int installmentCount,
    required DateTime firstDueDate,
    required String paymentMethod,
    required String amortizationMethod,
    required bool lateInterestEnabled,
    required double lateInterestRate,
    required double lateFeeBase,
    String? note,
    String? renegotiatedFrom,
  }) async {
    final simulation = simulateLoan(principal: principal, monthlyRate: monthlyRate, installmentCount: installmentCount, firstDueDate: firstDueDate, amortizationMethod: amortizationMethod);
    final inserted = await db.from('cobrapp_loans').insert({
      'user_id': uid,
      'customer_id': customerId,
      'principal': principal,
      'installments': installmentCount,
      'interest_rate': monthlyRate,
      'status': 'active',
      'total_amount': simulation.total,
      'total_interest': simulation.totalInterest,
      'interest_type': amortizationMethod == 'price' ? 'price' : 'simple',
      'payment_frequency': 'monthly',
      'start_date': DateTime.now().toIso8601String().substring(0, 10),
      'end_date': simulation.rows.last.dueDate.toIso8601String().substring(0, 10),
      'late_interest_enabled': lateInterestEnabled,
      'late_interest_rate': lateInterestRate,
      'late_fee_base': lateFeeBase,
      'default_payment_method': paymentMethod,
      'amortization_method': amortizationMethod,
      'note': note,
      'renegotiated_from': renegotiatedFrom,
      'updated_at': DateTime.now().toIso8601String(),
    }).select().single();
    final loan = Map<String, dynamic>.from(inserted);
    final loanId = loan['id'].toString();
    await db.from('cobrapp_installments').insert(simulation.rows.map((row) => {
      'user_id': uid,
      'loan_id': loanId,
      'customer_id': customerId,
      'number': row.number,
      'due_date': row.dueDate.toIso8601String().substring(0, 10),
      'amount': row.amount,
      'interest_amount': row.interestPart,
      'status': 'pending',
    }).toList());
    return {...loan, 'installment_amount': simulation.installment, 'total_interest': simulation.totalInterest};
  }

  Future<void> addInstallmentToLoan({required Map<String, dynamic> loan, required double amount, required DateTime dueDate}) async {
    final loanId = loan['id'].toString();
    final existing = await installments(loanId: loanId);
    final number = existing.isEmpty ? 1 : existing.map((e) => (e['number'] as num?)?.toInt() ?? 0).reduce(math.max) + 1;
    await db.from('cobrapp_installments').insert({'user_id': uid, 'loan_id': loanId, 'customer_id': loan['customer_id'], 'number': number, 'due_date': dueDate.toIso8601String().substring(0, 10), 'amount': amount, 'status': 'pending'});
    await _refreshLoanTotals(loanId);
  }

  Future<void> setLoanLateInterest({required String loanId, required bool enabled, required double rate}) async {
    await db.from('cobrapp_loans').update({'late_interest_enabled': enabled, 'late_interest_rate': rate, 'updated_at': DateTime.now().toIso8601String()}).eq('id', loanId).eq('user_id', uid);
  }

  Future<void> updateLateFeeBase({required String loanId, required double base}) async {
    await db.from('cobrapp_loans').update({'late_fee_base': base, 'late_fee': base, 'updated_at': DateTime.now().toIso8601String()}).eq('id', loanId).eq('user_id', uid);
  }

  double overdueInterestFor({required Map<String, dynamic> loan, required Map<String, dynamic> installment}) {
    if (loan['late_interest_enabled'] != true) return 0;
    final due = DateTime.tryParse(installment['due_date']?.toString() ?? '');
    if (due == null) return 0;
    final grace = (loan['days_of_grace'] as num?)?.toInt() ?? 0;
    final start = due.add(Duration(days: grace));
    final today = DateTime.now();
    if (!today.isAfter(start)) return 0;
    final daysLate = today.difference(start).inDays;
    final outstanding = math.max(0, ((installment['amount'] as num?)?.toDouble() ?? 0) - ((installment['paid_amount'] as num?)?.toDouble() ?? 0));
    final monthlyRate = (loan['late_interest_rate'] as num?)?.toDouble() ?? 0;
    return _round2(outstanding * (monthlyRate / 100) * (daysLate / 30));
  }

  double lateFeeFor({required Map<String, dynamic> loan, required Map<String, dynamic> installment}) {
    final due = DateTime.tryParse(installment['due_date']?.toString() ?? '');
    if (due == null || !DateTime.now().isAfter(due)) return 0;
    return _round2((loan['late_fee_base'] as num?)?.toDouble() ?? 0);
  }

  Future<Map<String, dynamic>> renegotiateLoan({
    required Map<String, dynamic> oldLoan,
    required double principal,
    required double monthlyRate,
    required int installmentCount,
    required DateTime firstDueDate,
    required String paymentMethod,
    required String amortizationMethod,
  }) async {
    final oldId = oldLoan['id'].toString();
    await db.from('cobrapp_installments').update({'status': 'renegotiated'}).eq('loan_id', oldId).eq('user_id', uid).neq('status', 'paid');
    await db.from('cobrapp_loans').update({'status': 'renegotiated', 'updated_at': DateTime.now().toIso8601String()}).eq('id', oldId).eq('user_id', uid);
    return createLoanDetailed(
      customerId: oldLoan['customer_id'].toString(), principal: principal, monthlyRate: monthlyRate, installmentCount: installmentCount,
      firstDueDate: firstDueDate, paymentMethod: paymentMethod, amortizationMethod: amortizationMethod,
      lateInterestEnabled: oldLoan['late_interest_enabled'] == true,
      lateInterestRate: (oldLoan['late_interest_rate'] as num?)?.toDouble() ?? 0,
      lateFeeBase: (oldLoan['late_fee_base'] as num?)?.toDouble() ?? 0,
      note: 'Renegociação do empréstimo $oldId', renegotiatedFrom: oldId,
    );
  }

  Future<double> outstandingForLoan(String loanId) async {
    final rows = await installments(loanId: loanId);
    return _round2(rows.where((row) => row['status'] != 'paid').fold<double>(0, (sum, row) => sum + math.max(0, ((row['amount'] as num?)?.toDouble() ?? 0) - ((row['paid_amount'] as num?)?.toDouble() ?? 0))));
  }

  Future<double> liquidateLoan({required Map<String, dynamic> loan, double discountPercent = 0}) async {
    final rows = await installments(loanId: loan['id'].toString());
    var totalPaid = 0.0;
    for (final row in rows.where((e) => e['status'] != 'paid')) {
      final outstanding = math.max(0, ((row['amount'] as num?)?.toDouble() ?? 0) - ((row['paid_amount'] as num?)?.toDouble() ?? 0));
      if (outstanding <= 0) continue;
      final net = _round2(outstanding * (1 - discountPercent / 100));
      final currentPaid = (row['paid_amount'] as num?)?.toDouble() ?? 0;
      final newAmount = _round2(currentPaid + net);
      await db.from('cobrapp_installments').update({'amount': newAmount, 'paid_amount': newAmount, 'status': 'paid', 'paid_at': DateTime.now().toIso8601String().substring(0, 10)}).eq('id', row['id']).eq('user_id', uid);
      await db.from('cobrapp_payments').insert({'user_id': uid, 'customer_id': row['customer_id'], 'loan_id': row['loan_id'], 'installment_id': row['id'], 'amount': net, 'method': loan['default_payment_method'] ?? 'Dinheiro', 'notes': discountPercent > 0 ? 'Liquidação antecipada com desconto de $discountPercent%' : 'Liquidação do empréstimo', 'type': 'total'});
      totalPaid += net;
    }
    await db.from('cobrapp_loans').update({'status': 'paid', 'early_discount_percent': discountPercent, 'updated_at': DateTime.now().toIso8601String()}).eq('id', loan['id']).eq('user_id', uid);
    return _round2(totalPaid);
  }

  Future<double> anticipateInstallment({required Map<String, dynamic> loan, required Map<String, dynamic> installment, required double discountPercent}) async {
    final currentPaid = (installment['paid_amount'] as num?)?.toDouble() ?? 0;
    final outstanding = math.max(0, ((installment['amount'] as num?)?.toDouble() ?? 0) - currentPaid);
    final net = _round2(outstanding * (1 - discountPercent / 100));
    final newAmount = _round2(currentPaid + net);
    await db.from('cobrapp_installments').update({'amount': newAmount, 'paid_amount': newAmount, 'status': 'paid', 'paid_at': DateTime.now().toIso8601String().substring(0, 10)}).eq('id', installment['id']).eq('user_id', uid);
    await db.from('cobrapp_payments').insert({'user_id': uid, 'customer_id': installment['customer_id'], 'loan_id': installment['loan_id'], 'installment_id': installment['id'], 'amount': net, 'method': loan['default_payment_method'] ?? 'Dinheiro', 'notes': discountPercent > 0 ? 'Pagamento antecipado com desconto de $discountPercent%' : 'Pagamento antecipado', 'type': 'total'});
    await _refreshLoanStatus(loan['id'].toString());
    return net;
  }

  Future<void> setPaymentCommitment({required String loanId, required DateTime date, required double amount, String? notes}) async {
    await db.from('cobrapp_loans').update({'commitment_date': date.toIso8601String().substring(0, 10), 'commitment_amount': amount, 'commitment_notes': notes, 'updated_at': DateTime.now().toIso8601String()}).eq('id', loanId).eq('user_id', uid);
  }

  Future<void> _refreshLoanTotals(String loanId) async {
    final rows = await installments(loanId: loanId);
    final total = rows.fold<double>(0, (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0));
    await db.from('cobrapp_loans').update({'installments': rows.length, 'total_amount': _round2(total), 'updated_at': DateTime.now().toIso8601String()}).eq('id', loanId).eq('user_id', uid);
  }

  Future<void> _refreshLoanStatus(String loanId) async {
    final rows = await installments(loanId: loanId);
    if (rows.isNotEmpty && rows.every((row) => row['status'] == 'paid')) {
      await db.from('cobrapp_loans').update({'status': 'paid', 'updated_at': DateTime.now().toIso8601String()}).eq('id', loanId).eq('user_id', uid);
    }
  }
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

class DateUtilsHelper {
  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
}
