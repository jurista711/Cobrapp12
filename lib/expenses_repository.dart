import 'data/cobrapp_repository.dart';

extension ExpensesRepository on CobrAppRepository {
  static const categories = <String>[
    'Aluguel',
    'Energia',
    'Água',
    'Internet',
    'Material',
    'Folha de pagamento',
    'Impostos',
    'Outros',
  ];

  Future<List<Map<String, dynamic>>> expensesDetailed() async {
    return List<Map<String, dynamic>>.from(
      await db
          .from('cobrapp_expenses')
          .select('id,user_id,amount,description,category,spent_at,status,notes,created_at')
          .eq('user_id', uid)
          .order('spent_at', ascending: false),
    );
  }

  Future<void> createExpense({
    required String description,
    required String category,
    required double amount,
    required DateTime date,
    required String status,
    String? notes,
  }) async {
    await db.from('cobrapp_expenses').insert({
      'user_id': uid,
      'description': description.trim(),
      'category': category,
      'amount': amount,
      'spent_at': date.toIso8601String().substring(0, 10),
      'status': status,
      'notes': _clean(notes),
    });
  }

  Future<void> updateExpense({
    required String id,
    required String description,
    required String category,
    required double amount,
    required DateTime date,
    required String status,
    String? notes,
  }) async {
    await db
        .from('cobrapp_expenses')
        .update({
          'description': description.trim(),
          'category': category,
          'amount': amount,
          'spent_at': date.toIso8601String().substring(0, 10),
          'status': status,
          'notes': _clean(notes),
        })
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> removeExpense(String id) async {
    await db
        .from('cobrapp_expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);
  }

  Map<String, dynamic> expenseReport(
    List<Map<String, dynamic>> rows, {
    DateTime? from,
    DateTime? to,
    String? category,
    String? status,
    double? minValue,
    double? maxValue,
  }) {
    final filtered = rows.where((row) {
      final date = DateTime.tryParse(row['spent_at']?.toString() ?? '');
      final value = (row['amount'] as num?)?.toDouble() ?? 0;
      if (date != null && from != null && date.isBefore(DateTime(from.year, from.month, from.day))) return false;
      if (date != null && to != null && date.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59))) return false;
      if (category != null && category.isNotEmpty && row['category'] != category) return false;
      if (status != null && status.isNotEmpty && row['status'] != status) return false;
      if (minValue != null && value < minValue) return false;
      if (maxValue != null && value > maxValue) return false;
      return true;
    }).toList();

    final byCategory = <String, double>{};
    final months = <String>{};
    var total = 0.0;
    for (final row in filtered) {
      final value = (row['amount'] as num?)?.toDouble() ?? 0;
      total += value;
      final cat = row['category']?.toString() ?? 'Outros';
      byCategory[cat] = (byCategory[cat] ?? 0) + value;
      final date = DateTime.tryParse(row['spent_at']?.toString() ?? '');
      if (date != null) {
        months.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
      }
    }
    final monthlyAverage = months.isEmpty ? 0.0 : total / months.length;
    return {
      'rows': filtered,
      'total': total,
      'monthly_average': monthlyAverage,
      'by_category': byCategory,
    };
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
