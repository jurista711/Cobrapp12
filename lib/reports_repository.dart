import 'data/auth_repository.dart';
import 'data/cobrapp_repository.dart';
import 'customers_repository.dart';

class ReportsRepository {
  final CobrAppRepository _repo = CobrAppRepository();
  final CustomersRepository _customers = CustomersRepository();
  final AuthRepository _auth = AuthRepository();

  bool get hasPremiumAccess => _auth.hasPremiumAccess || _customers.isPremium;

  Future<Map<String, dynamic>> load() async {
    final portfolio = await _repo.portfolioReport();
    final customersPerDay = await _customers.customersPerDay();
    final topCustomers = await _customers.customersMostPaid();

    final loans = List<Map<String, dynamic>>.from(portfolio['loans'] as List? ?? const []);
    final installments = List<Map<String, dynamic>>.from(portfolio['installments'] as List? ?? const []);
    final payments = List<Map<String, dynamic>>.from(portfolio['payments'] as List? ?? const []);

    final today = DateTime.now();
    final overdueLoanIds = <String>{};
    for (final row in installments) {
      final status = row['status']?.toString() ?? '';
      final due = DateTime.tryParse(row['due_date']?.toString() ?? '');
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final paid = (row['paid_amount'] as num?)?.toDouble() ?? 0;
      if (status != 'paid' && due != null && due.isBefore(DateTime(today.year, today.month, today.day)) && amount > paid) {
        overdueLoanIds.add(row['loan_id']?.toString() ?? '');
      }
    }

    int active = 0;
    int paid = 0;
    int renegotiated = 0;
    for (final loan in loans) {
      switch (loan['status']?.toString()) {
        case 'paid':
          paid++;
          break;
        case 'renegotiated':
          renegotiated++;
          break;
        default:
          active++;
      }
    }

    final loaned = (portfolio['loaned'] as num?)?.toDouble() ?? 0;
    final received = (portfolio['received'] as num?)?.toDouble() ?? 0;
    final pending = (portfolio['pending'] as num?)?.toDouble() ?? 0;
    final overdue = (portfolio['overdue'] as num?)?.toDouble() ?? 0;
    final averageTicket = loans.isEmpty ? 0.0 : loaned / loans.length;
    final delinquency = pending <= 0 ? 0.0 : overdue / pending * 100;
    final recovery = loaned <= 0 ? 0.0 : received / loaned * 100;

    final paidByLoan = <String, double>{};
    for (final p in payments) {
      final id = p['loan_id']?.toString();
      if (id == null || id.isEmpty) continue;
      paidByLoan[id] = (paidByLoan[id] ?? 0) + ((p['amount'] as num?)?.toDouble() ?? 0);
    }
    final pendingByLoan = <String, double>{};
    for (final i in installments) {
      final id = i['loan_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final amount = (i['amount'] as num?)?.toDouble() ?? 0;
      final paidAmount = (i['paid_amount'] as num?)?.toDouble() ?? 0;
      pendingByLoan[id] = (pendingByLoan[id] ?? 0) + (amount - paidAmount).clamp(0, double.infinity).toDouble();
    }

    final detailedLoans = loans.map((loan) {
      final customer = loan['cobrapp_customers'];
      final customerName = customer is Map ? (customer['name']?.toString() ?? 'Cliente') : 'Cliente';
      final id = loan['id']?.toString() ?? '';
      return {
        'id': id,
        'customer': customerName,
        'principal': (loan['principal'] as num?)?.toDouble() ?? 0,
        'total': (loan['total_amount'] as num?)?.toDouble() ?? 0,
        'received': paidByLoan[id] ?? 0,
        'pending': pendingByLoan[id] ?? 0,
        'status': loan['status']?.toString() ?? 'active',
        'created_at': loan['created_at']?.toString(),
        'overdue': overdueLoanIds.contains(id),
      };
    }).toList();

    return {
      'status': {
        'active': active,
        'paid': paid,
        'overdue': overdueLoanIds.where((e) => e.isNotEmpty).length,
        'renegotiated': renegotiated,
      },
      'metrics': {
        'loaned': loaned,
        'received': received,
        'pending': pending,
        'overdue': overdue,
        'average_ticket': averageTicket,
        'delinquency_percent': delinquency,
        'recovery_percent': recovery,
      },
      'detailed_loans': detailedLoans,
      'customers_per_day': customersPerDay,
      'top_customers': topCustomers,
    };
  }
}
