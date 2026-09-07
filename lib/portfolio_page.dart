import 'package:flutter/material.dart';

import 'data/cobrapp_repository.dart';

class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});

  Future<Map<String, dynamic>> _load() async {
    final repo = CobrAppRepository();
    final results = await Future.wait([
      repo.loans(),
      repo.installments(),
    ]);
    final loans = results[0];
    final installments = results[1];

    final activeLoans = loans.where((loan) => loan['status'] == 'active').toList();
    final activeIds = activeLoans.map((loan) => loan['id'].toString()).toSet();
    final activeInstallments = installments
        .where((item) => activeIds.contains(item['loan_id']?.toString()))
        .toList();

    double number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    final principal = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + number(loan['principal']),
    );
    final contractedTotal = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + number(loan['total_amount']),
    );
    final contractedInterest = (contractedTotal - principal).clamp(0, double.infinity).toDouble();
    final pending = activeInstallments.fold<double>(
      0,
      (sum, item) => sum + (number(item['amount']) - number(item['paid_amount'])).clamp(0, double.infinity),
    );
    final received = activeInstallments.fold<double>(
      0,
      (sum, item) => sum + number(item['paid_amount']),
    );
    final weightedRate = principal <= 0 ? 0.0 : (contractedInterest / principal) * 100;

    final customerMap = <String, Map<String, dynamic>>{};
    for (final loan in activeLoans) {
      final customerId = loan['customer_id']?.toString() ?? '';
      final customer = loan['cobrapp_customers'];
      final customerName = customer is Map ? '${customer['name'] ?? 'Cliente'}' : 'Cliente';
      final row = customerMap.putIfAbsent(
        customerId,
        () => {
          'name': customerName,
          'principal': 0.0,
          'total': 0.0,
          'loans': 0,
        },
      );
      row['principal'] = (row['principal'] as double) + number(loan['principal']);
      row['total'] = (row['total'] as double) + number(loan['total_amount']);
      row['loans'] = (row['loans'] as int) + 1;
    }

    final customers = customerMap.values.toList()
      ..sort((a, b) => (b['principal'] as double).compareTo(a['principal'] as double));

    return {
      'principal': principal,
      'interest': contractedInterest,
      'total': contractedTotal,
      'pending': pending,
      'received': received,
      'rate': weightedRate,
      'loans': activeLoans.length,
      'customers': customers,
    };
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    final parts = fixed.split(',');
    var integer = parts[0];
    final negative = integer.startsWith('-');
    if (negative) integer = integer.substring(1);
    final groups = <String>[];
    for (var i = integer.length; i > 0; i -= 3) {
      final start = i - 3 < 0 ? 0 : i - 3;
      groups.insert(0, integer.substring(start, i));
    }
    return '${negative ? '-' : ''}R\$ ${groups.join('.').isEmpty ? '0' : groups.join('.')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Não foi possível carregar a carteira.\n${snapshot.error}'),
            ),
          );
        }

        final data = snapshot.data ?? <String, dynamic>{};
        final principal = (data['principal'] as num?)?.toDouble() ?? 0;
        final interest = (data['interest'] as num?)?.toDouble() ?? 0;
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final pending = (data['pending'] as num?)?.toDouble() ?? 0;
        final received = (data['received'] as num?)?.toDouble() ?? 0;
        final rate = (data['rate'] as num?)?.toDouble() ?? 0;
        final loanCount = data['loans'] ?? 0;
        final customers = List<Map<String, dynamic>>.from(data['customers'] ?? const []);

        return RefreshIndicator(
          onRefresh: () async {
            // The FutureBuilder is recreated by the surrounding navigation when needed.
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'Gestão da Carteira',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Visão de quanto está na rua, quanto de juros está previsto e quanto você espera receber.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              _HeroCard(
                title: 'Total da carteira',
                value: _money(total),
                subtitle: '${_money(principal)} emprestados + ${_money(interest)} de juros previstos',
                icon: Icons.account_balance_wallet_rounded,
                colors: [cs.primary, const Color(0xFFA855F7)],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Na rua',
                      value: _money(principal),
                      caption: 'Capital emprestado',
                      icon: Icons.trending_up_rounded,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Juros',
                      value: _money(interest),
                      caption: 'Previstos nos ativos',
                      icon: Icons.percent_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Em aberto',
                      value: _money(pending),
                      caption: 'Parcelas ainda não pagas',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Recebido',
                      value: _money(received),
                      caption: 'Pagamentos registrados',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(Icons.percent_rounded, color: cs.onPrimaryContainer),
                  ),
                  title: const Text('Taxa média da carteira', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Relação entre juros previstos e capital emprestado'),
                  trailing: Text('${rate.toStringAsFixed(1).replaceAll('.', ',')}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text('Carteira ativa', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                  Text('$loanCount empréstimos', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 10),
              if (customers.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Ainda não há empréstimos ativos na carteira.', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              else
                ...customers.map((customer) {
                  final customerPrincipal = (customer['principal'] as num?)?.toDouble() ?? 0;
                  final customerTotal = (customer['total'] as num?)?.toDouble() ?? 0;
                  final customerInterest = (customerTotal - customerPrincipal).clamp(0, double.infinity).toDouble();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${customer['loans']}')),
                      title: Text('${customer['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${_money(customerPrincipal)} emprestados • ${_money(customerInterest)} de juros'),
                      trailing: Text(_money(customerTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  );
                }),
              const SizedBox(height: 10),
              Text(
                'Os valores são calculados automaticamente a partir dos empréstimos ativos e das parcelas registradas no banco.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  const _HeroCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.colors});

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
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              Icon(icon, color: Colors.white.withValues(alpha: 0.85)),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.caption, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            FittedBox(alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            const SizedBox(height: 3),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
