import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final principal = TextEditingController();
  final rate = TextEditingController(text: '20');
  final installments = TextEditingController(text: '4');

  String interestType = 'fixed';
  String paymentType = 'installments';

  double? total;
  double? interest;
  double? installmentValue;

  String money(double value) =>
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

  @override
  void dispose() {
    principal.dispose();
    rate.dispose();
    installments.dispose();
    super.dispose();
  }

  void calculate() {
    final p = double.tryParse(principal.text.replaceAll(',', '.'));
    final r = double.tryParse(rate.text.replaceAll(',', '.'));
    final n = int.tryParse(installments.text);

    if (p == null || p <= 0 || r == null || r < 0 || n == null || n <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe valores válidos para calcular.')),
      );
      return;
    }

    double t;
    if (interestType == 'compound') {
      t = p * _pow(1 + r / 100, n);
    } else {
      t = paymentType == 'single'
          ? p * (1 + (r / 100) * n)
          : p * (1 + r / 100);
    }

    setState(() {
      total = t;
      interest = t - p;
      installmentValue = paymentType == 'single' ? t : t / n;
    });
  }

  double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  void clear() {
    principal.clear();
    rate.text = '20';
    installments.text = '4';
    setState(() {
      total = null;
      interest = null;
      installmentValue = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6D28D9), Color(0xFFA855F7)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calculate_rounded, color: Colors.white, size: 34),
                SizedBox(height: 12),
                Text(
                  'Calculadora de empréstimos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Simule juros, parcelas e total antes de fechar o empréstimo.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: principal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor emprestado',
                    prefixText: 'R\$ ',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: interestType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de juros',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('Juros fixos')),
                    DropdownMenuItem(value: 'compound', child: Text('Juros compostos')),
                  ],
                  onChanged: (v) => setState(() => interestType = v ?? 'fixed'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: paymentType,
                  decoration: const InputDecoration(
                    labelText: 'Forma de pagamento',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'installments', child: Text('Parcelado')),
                    DropdownMenuItem(value: 'single', child: Text('Pagamento único')),
                  ],
                  onChanged: (v) => setState(() => paymentType = v ?? 'installments'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Juros por período (%)',
                    prefixIcon: Icon(Icons.trending_up_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: installments,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: paymentType == 'single'
                        ? 'Períodos até o pagamento'
                        : 'Quantidade de parcelas',
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: calculate,
                        icon: const Icon(Icons.calculate),
                        label: const Text('Calcular'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: clear,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (total != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultCard(
                  title: 'Total a receber',
                  value: money(total!),
                  icon: Icons.account_balance_wallet_rounded,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResultCard(
                  title: 'Juros',
                  value: money(interest!),
                  icon: Icons.percent_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.payments_rounded, color: cs.onPrimaryContainer),
              ),
              title: Text(paymentType == 'single' ? 'Pagamento único' : 'Valor de cada parcela'),
              subtitle: const Text('Resultado da simulação'),
              trailing: Text(
                money(installmentValue!),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          color: cs.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Dica: use esta calculadora para simular o negócio antes de criar o empréstimo. '
              'O cálculo de juros compostos considera a capitalização a cada período.',
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
