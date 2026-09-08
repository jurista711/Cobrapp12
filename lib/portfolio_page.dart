import 'package:flutter/material.dart';

import 'data/cobrapp_repository.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _money(double value) {
    final negative = value < 0;
    final absolute = value.abs().toStringAsFixed(2).replaceAll('.', ',');
    final parts = absolute.split(',');
    var integer = parts.first;
    final groups = <String>[];

    for (var end = integer.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.insert(0, integer.substring(start, end));
    }

    integer = groups.join('.');
    return '${negative ? '-' : ''}R\$ $integer,${parts.last}';
  }

  DateTime? _date(dynamic value) => DateTime.tryParse('$value');

  Future<Map<String, dynamic>> _load() async {
    final repo = CobrAppRepository();

    final loans = List<Map<String, dynamic>>.from(
      await repo.db
          .from('cobrapp_loans')
          .select(
            'id,customer_id,principal,total_amount,status,created_at,cobrapp_customers(name)',
          )
          .eq('user_id', repo.uid)
          .order('created_at', ascending: false),
    );

    final installments = List<Map<String, dynamic>>.from(
      await repo.db
          .from('cobrapp_installments')
          .select(
            'id,loan_id,customer_id,amount,paid_amount,interest_amount,interest_paid,status,due_date',
          )
          .eq('user_id', repo.uid)
          .order('due_date'),
    );

    final payments = List<Map<String, dynamic>>.from(
      await repo.db
          .from('cobrapp_payments')
          .select('amount,paid_at,type,customer_id')
          .eq('user_id', repo.uid)
          .order('paid_at', ascending: false),
    );

    final expenses = List<Map<String, dynamic>>.from(
      await repo.db
          .from('cobrapp_expenses')
          .select('amount,spent_at')
          .eq('user_id', repo.uid)
          .order('spent_at', ascending: false),
    );

    final activeLoans = loans.where((loan) => loan['status'] == 'active').toList();
    final activeIds = activeLoans.map((loan) => loan['id'].toString()).toSet();
    final activeInstallments = installments
        .where((item) => activeIds.contains(item['loan_id']?.toString()))
        .toList();

    final principal = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + _number(loan['principal']),
    );
    final expectedTotal = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + _number(loan['total_amount']),
    );
    final projectedInterest =
        (expectedTotal - principal).clamp(0, double.infinity).toDouble();

    final pending = activeInstallments.fold<double>(
      0,
      (sum, item) =>
          sum + (_number(item['amount']) - _number(item['paid_amount']))
              .clamp(0, double.infinity),
    );

    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final overdue = activeInstallments.where((item) {
      final due = _date(item['due_date']);
      return item['status'] != 'paid' &&
          due != null &&
          due.isBefore(startOfToday);
    }).fold<double>(
      0,
      (sum, item) =>
          sum + (_number(item['amount']) - _number(item['paid_amount']))
              .clamp(0, double.infinity),
    );

    final received = payments.fold<double>(
      0,
      (sum, payment) => sum + _number(payment['amount']),
    );
    final expensesTotal = expenses.fold<double>(
      0,
      (sum, expense) => sum + _number(expense['amount']),
    );

    final projectedProfit = projectedInterest - expensesTotal;

    final months = <Map<String, dynamic>>[];
    for (var offset = 5; offset >= 0; offset--) {
      final month = DateTime(today.year, today.month - offset, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);
      var loaned = 0.0;
      var receivedMonth = 0.0;
      var expenseMonth = 0.0;

      for (final loan in loans) {
        final created = _date(loan['created_at']);
        if (created != null &&
            !created.isBefore(month) &&
            created.isBefore(nextMonth)) {
          loaned += _number(loan['principal']);
        }
      }

      for (final payment in payments) {
        final paidAt = _date(payment['paid_at']);
        if (paidAt != null &&
            !paidAt.isBefore(month) &&
            paidAt.isBefore(nextMonth)) {
          receivedMonth += _number(payment['amount']);
        }
      }

      for (final expense in expenses) {
        final spentAt = _date(expense['spent_at']);
        if (spentAt != null &&
            !spentAt.isBefore(month) &&
            spentAt.isBefore(nextMonth)) {
          expenseMonth += _number(expense['amount']);
        }
      }

      months.add({
        'label': '${month.month.toString().padLeft(2, '0')}/${month.year.toString().substring(2)}',
        'loaned': loaned,
        'received': receivedMonth,
        'expense': expenseMonth,
      });
    }

    return {
      'principal': principal,
      'expectedTotal': expectedTotal,
      'interest': projectedInterest,
      'pending': pending,
      'overdue': overdue,
      'received': received,
      'expenses': expensesTotal,
      'projectedProfit': projectedProfit,
      'rate': principal <= 0 ? 0 : (projectedInterest / principal) * 100,
      'loans': activeLoans.length,
      'months': months,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar a carteira.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final colors = Theme.of(context).colorScheme;
        final months = List<Map<String, dynamic>>.from(data['months'] as List);

        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _load());
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Gestão da Carteira',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Visão do dinheiro na rua, juros previstos, recebimentos, despesas e risco da carteira.',
              ),
              const SizedBox(height: 18),
              _HeroCard(
                title: 'Total da carteira',
                value: _money(_number(data['expectedTotal'])),
                subtitle:
                    '${_money(_number(data['principal']))} de capital + ${_money(_number(data['interest']))} de juros previstos',
                colors: [colors.primary, const Color(0xFFA855F7)],
              ),
              const SizedBox(height: 12),
              _MetricGrid(
                cards: [
                  _MetricCard(
                    title: 'Na rua',
                    value: _money(_number(data['principal'])),
                    subtitle: 'Capital emprestado',
                    icon: Icons.trending_up_rounded,
                    color: colors.primary,
                  ),
                  _MetricCard(
                    title: 'Juros previstos',
                    value: _money(_number(data['interest'])),
                    subtitle: 'Receita projetada',
                    icon: Icons.percent_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                  _MetricCard(
                    title: 'Capital recebido',
                    value: _money(
                      (_number(data['received']) - _number(data['interest']))
                          .clamp(0, double.infinity)
                          .toDouble(),
                    ),
                    subtitle: 'Estimativa de principal recuperado',
                    icon: Icons.account_balance_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  _MetricCard(
                    title: 'Recebido',
                    value: _money(_number(data['received'])),
                    subtitle: 'Total de pagamentos',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF16A34A),
                  ),
                  _MetricCard(
                    title: 'Inadimplência',
                    value: _money(_number(data['overdue'])),
                    subtitle: 'Saldo vencido',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                  _MetricCard(
                    title: 'Lucro previsto',
                    value: _money(_number(data['projectedProfit'])),
                    subtitle: 'Juros previstos - despesas',
                    icon: Icons.auto_graph_rounded,
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text(
                    'Taxa da carteira',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${_number(data['loans']).toInt()} empréstimos ativos'),
                  trailing: Text(
                    '${_number(data['rate']).toStringAsFixed(1).replaceAll('.', ',')}%',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Evolução dos últimos 6 meses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _PortfolioChart(months: months),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Barras: emprestado, recebido e despesas. Os valores são calculados diretamente do banco.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> cards;

  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = (width - 42) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cards
          .map((card) => SizedBox(width: cardWidth, child: card))
          .toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 9),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            FittedBox(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final List<Color> colors;

  const _HeroCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _PortfolioChart extends StatelessWidget {
  final List<Map<String, dynamic>> months;

  const _PortfolioChart({required this.months});

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    var maxValue = 1.0;
    for (final month in months) {
      maxValue = maxValue < _number(month['loaned'])
          ? _number(month['loaned'])
          : maxValue;
      maxValue = maxValue < _number(month['received'])
          ? _number(month['received'])
          : maxValue;
      maxValue = maxValue < _number(month['expense'])
          ? _number(month['expense'])
          : maxValue;
    }

    return SizedBox(
      height: 230,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: months.map((month) {
          final values = [
            _number(month['loaned']),
            _number(month['received']),
            _number(month['expense']),
          ];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(values.length, (index) {
                        final value = values[index];
                        final color = index == 0
                            ? const Color(0xFF7C3AED)
                            : index == 1
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626);

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              height: 150 * (value / maxValue),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${month['label']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
