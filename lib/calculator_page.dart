import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

enum _InterestMode { principal, perInstallment, compoundBank }
enum _PaymentFrequency { daily, weekly, biweekly, monthly, manual, monthDays }
enum _TargetField { rate, installment }

class _CalculatorPageState extends State<CalculatorPage> {
  final _principal = TextEditingController();
  final _installments = TextEditingController(text: '5');
  final _rate = TextEditingController(text: '30');
  final _desiredInstallment = TextEditingController(text: '910');
  final _graceDays = TextEditingController(text: '0');
  final _lateRate = TextEditingController(text: '1');
  final _lateFee = TextEditingController(text: '7');
  final _manualDays = TextEditingController(text: '30');
  final _monthDays = TextEditingController(text: '8');
  final _note = TextEditingController();

  _InterestMode _interestMode = _InterestMode.principal;
  _PaymentFrequency _frequency = _PaymentFrequency.monthly;
  _TargetField _target = _TargetField.rate;
  DateTime _creditDate = DateTime.now();
  bool _addNote = false;
  bool _lateInterest = false;
  bool _showSimulation = false;
  List<_PaymentRow> _plan = const [];
  double? _total;
  double? _interest;
  double? _payment;
  double? _effectiveRate;
  String? _error;

  String money(double value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
  String date(DateTime value) => DateFormat('dd MMM. yyyy', 'pt_BR').format(value).toUpperCase();

  @override
  void dispose() {
    for (final c in [
      _principal,
      _installments,
      _rate,
      _desiredInstallment,
      _graceDays,
      _lateRate,
      _lateFee,
      _manualDays,
      _monthDays,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final normalized = raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
    return double.tryParse(normalized);
  }

  int? _integer(TextEditingController c) => int.tryParse(c.text.trim());

  String get _interestLabel {
    switch (_interestMode) {
      case _InterestMode.principal:
        return 'Capital inicial';
      case _InterestMode.perInstallment:
        return 'Cada parcela';
      case _InterestMode.compoundBank:
        return 'Juros compostos bancários';
    }
  }

  String get _frequencyLabel {
    switch (_frequency) {
      case _PaymentFrequency.daily:
        return 'Diário';
      case _PaymentFrequency.weekly:
        return 'Semanal';
      case _PaymentFrequency.biweekly:
        return 'Quinzenal';
      case _PaymentFrequency.monthly:
        return 'Mensal';
      case _PaymentFrequency.manual:
        return 'Inserir manual';
      case _PaymentFrequency.monthDays:
        return 'Dias Específicos do Mês';
    }
  }

  void _swapTarget() => setState(() => _target = _target == _TargetField.rate ? _TargetField.installment : _TargetField.rate);

  double _compoundPayment(double principal, double ratePercent, int n) {
    final r = ratePercent / 100;
    if (r.abs() < 1e-12) return principal / n;
    return principal * r / (1 - math.pow(1 + r, -n));
  }

  double _rateForPayment(double principal, double payment, int n) {
    if (payment <= 0) return 0;
    var lo = -0.999999;
    var hi = 10.0;
    for (var i = 0; i < 100; i++) {
      final mid = (lo + hi) / 2;
      final value = mid.abs() < 1e-12
          ? principal / n
          : principal * mid / (1 - math.pow(1 + mid, -n));
      if (value < payment) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return ((lo + hi) / 2) * 100;
  }

  DateTime _nextDate(DateTime current) {
    switch (_frequency) {
      case _PaymentFrequency.daily:
        return current.add(const Duration(days: 1));
      case _PaymentFrequency.weekly:
        return current.add(const Duration(days: 7));
      case _PaymentFrequency.biweekly:
        return current.add(const Duration(days: 14));
      case _PaymentFrequency.monthly:
        return DateTime(
          current.year,
          current.month + 1,
          math.min(current.day, DateUtils.getDaysInMonth(current.year, current.month + 1)),
        );
      case _PaymentFrequency.manual:
        final days = _integer(_manualDays) ?? 30;
        return current.add(Duration(days: math.max(1, days)));
      case _PaymentFrequency.monthDays:
        final values = _monthDays.text
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .where((e) => e >= 1 && e <= 31)
            .toList()
          ..sort();
        if (values.isEmpty) {
          return DateTime(current.year, current.month + 1, math.min(current.day, DateUtils.getDaysInMonth(current.year, current.month + 1)));
        }
        final later = values.where((d) => d > current.day).toList();
        final day = later.isNotEmpty ? later.first : values.first;
        final month = current.month + (later.isNotEmpty ? 0 : 1);
        final year = current.year + (month - 1) ~/ 12;
        final normalizedMonth = ((month - 1) % 12) + 1;
        return DateTime(year, normalizedMonth, math.min(day, DateUtils.getDaysInMonth(year, normalizedMonth)));
    }
  }

  void _simulate() {
    FocusScope.of(context).unfocus();
    final principal = _number(_principal);
    final n = _integer(_installments);
    if (principal == null || principal <= 0 || n == null || n <= 0) {
      setState(() => _error = 'Informe o valor do crédito e o número de cotas.');
      return;
    }

    var rate = _number(_rate) ?? 0;
    if (_target == _TargetField.installment) {
      final desired = _number(_desiredInstallment);
      if (desired == null || desired <= 0) {
        setState(() => _error = 'Informe a parcela desejada.');
        return;
      }
      switch (_interestMode) {
        case _InterestMode.principal:
          rate = ((desired * n / principal) - 1) * 100;
        case _InterestMode.perInstallment:
          rate = ((desired - principal / n) / principal) * 100;
        case _InterestMode.compoundBank:
          rate = _rateForPayment(principal, desired, n);
      }
      _rate.text = rate.clamp(0, 9999).toStringAsFixed(2);
    }

    if (rate < 0 || rate > 9999) {
      setState(() => _error = 'A taxa de juros precisa estar entre 0% e 9999%.');
      return;
    }

    if (_lateInterest) {
      final grace = _integer(_graceDays);
      final lateRate = _number(_lateRate);
      final fee = _number(_lateFee);
      if (grace == null || grace < 0 || lateRate == null || lateRate < 0 || fee == null || fee < 0) {
        setState(() => _error = 'Preencha corretamente carência, juros de mora e multa.');
        return;
      }
    }

    double payment;
    double totalInterest;
    switch (_interestMode) {
      case _InterestMode.principal:
        totalInterest = principal * rate / 100;
        payment = (principal + totalInterest) / n;
      case _InterestMode.perInstallment:
        final interestEach = principal * rate / 100;
        payment = principal / n + interestEach;
        totalInterest = interestEach * n;
      case _InterestMode.compoundBank:
        payment = _compoundPayment(principal, rate, n);
        totalInterest = payment * n - principal;
    }

    final rows = <_PaymentRow>[];
    var due = _creditDate;
    var balance = principal;
    for (var i = 1; i <= n; i++) {
      due = _nextDate(due);
      double rowInterest;
      double rowCapital;
      if (_interestMode == _InterestMode.perInstallment) {
        rowInterest = principal * rate / 100;
        rowCapital = principal / n;
      } else if (_interestMode == _InterestMode.compoundBank) {
        rowInterest = balance * rate / 100;
        rowCapital = math.max(0, payment - rowInterest);
        if (i == n) rowCapital = balance;
      } else {
        rowInterest = totalInterest / n;
        rowCapital = principal / n;
      }
      balance = math.max(0, balance - rowCapital);
      rows.add(_PaymentRow(number: i, due: due, capital: rowCapital, interest: rowInterest, total: rowCapital + rowInterest));
    }

    setState(() {
      _error = null;
      _total = payment * n;
      _interest = totalInterest;
      _payment = payment;
      _effectiveRate = rate;
      _plan = rows;
      _showSimulation = true;
    });
  }

  void _clear() {
    _principal.clear();
    _installments.text = '5';
    _rate.text = '30';
    _desiredInstallment.text = '910';
    _graceDays.text = '0';
    _lateRate.text = '1';
    _lateFee.text = '7';
    _showSimulation = false;
    _plan = const [];
    setState(() {
      _error = null;
      _total = null;
      _interest = null;
      _payment = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _creditDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _creditDate = picked);
  }

  InputDecoration _dec(String label, {IconData? icon, String? prefix}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        prefixText: prefix,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.55),
      );

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
              gradient: LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFFEC4899), Color(0xFFEF4444)]),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calculate_rounded, color: Colors.white, size: 34),
                SizedBox(height: 10),
                Text('Simular crédito', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Monte o crédito, escolha a frequência e veja o plano completo.', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: const Color(0xFF160D27),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: cs.primary.withOpacity(.35))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<_InterestMode>(
                  initialValue: _interestMode,
                  decoration: _dec('Tipo de juros', icon: Icons.percent_rounded),
                  items: const [
                    DropdownMenuItem(value: _InterestMode.principal, child: Text('Capital inicial')),
                    DropdownMenuItem(value: _InterestMode.perInstallment, child: Text('Cada parcela')),
                    DropdownMenuItem(value: _InterestMode.compoundBank, child: Text('Juros compostos bancários')),
                  ],
                  onChanged: (v) => setState(() {
                    _interestMode = v ?? _InterestMode.principal;
                    _showSimulation = false;
                  }),
                ),
                const SizedBox(height: 10),
                TextField(controller: _principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('Valor', icon: Icons.attach_money_rounded, prefix: 'R\$ ')),
                const SizedBox(height: 10),
                TextField(controller: _installments, keyboardType: TextInputType.number, decoration: _dec('Cotas', icon: Icons.format_list_numbered_rounded)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('Juros do crédito', icon: Icons.percent_rounded))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(onPressed: _swapTarget, tooltip: 'Alternar campo calculado', icon: const Icon(Icons.swap_horiz_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _desiredInstallment, enabled: _target == _TargetField.installment, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('Parcela desejada', icon: Icons.payments_rounded, prefix: 'R\$ '))),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: Text(_target == _TargetField.rate ? 'A taxa é a referência' : 'A parcela desejada é a referência', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                const SizedBox(height: 10),
                DropdownButtonFormField<_PaymentFrequency>(
                  initialValue: _frequency,
                  decoration: _dec('Frequência de Pagamento', icon: Icons.event_repeat_rounded),
                  items: const [
                    DropdownMenuItem(value: _PaymentFrequency.daily, child: Text('Diário')),
                    DropdownMenuItem(value: _PaymentFrequency.weekly, child: Text('Semanal')),
                    DropdownMenuItem(value: _PaymentFrequency.biweekly, child: Text('Quinzenal')),
                    DropdownMenuItem(value: _PaymentFrequency.monthly, child: Text('Mensal')),
                    DropdownMenuItem(value: _PaymentFrequency.manual, child: Text('Inserir manual')),
                    DropdownMenuItem(value: _PaymentFrequency.monthDays, child: Text('Dias Específicos do Mês')),
                  ],
                  onChanged: (v) => setState(() {
                    _frequency = v ?? _PaymentFrequency.monthly;
                    _showSimulation = false;
                  }),
                ),
                if (_frequency == _PaymentFrequency.manual) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _manualDays, keyboardType: TextInputType.number, decoration: _dec('Intervalo entre pagamentos (dias)', icon: Icons.today_rounded)),
                ],
                if (_frequency == _PaymentFrequency.monthDays) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _monthDays, keyboardType: TextInputType.text, decoration: _dec('Dias do mês', icon: Icons.calendar_month_rounded), maxLength: 30),
                  Align(alignment: Alignment.centerLeft, child: Text('Exemplo: 5, 15, 25', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                ],
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(decoration: _dec('Data do Crédito', icon: Icons.calendar_today_rounded), child: Text(date(_creditDate))),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adicionar Nota'),
                  value: _addNote,
                  onChanged: (v) => setState(() => _addNote = v),
                ),
                if (_addNote) TextField(controller: _note, maxLines: 2, decoration: _dec('Nota', icon: Icons.note_alt_outlined)),
                const Divider(height: 18),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativar Juros de Mora'),
                  subtitle: Text('Cobrar juros sobre valores em atraso após a carência.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  value: _lateInterest,
                  onChanged: (v) => setState(() {
                    _lateInterest = v;
                    _showSimulation = false;
                  }),
                ),
                if (_lateInterest) ...[
                  TextField(controller: _graceDays, keyboardType: TextInputType.number, decoration: _dec('Dias de Carência', icon: Icons.calendar_today_rounded)),
                  const SizedBox(height: 10),
                  TextField(controller: _lateRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('Taxa de Juros de Mora (%)', icon: Icons.percent_rounded)),
                  const SizedBox(height: 10),
                  TextField(controller: _lateFee, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec('Valor da Multa por Atraso', icon: Icons.attach_money_rounded, prefix: 'R\$ ')),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: Text('Exemplo: uma parcela em atraso aplica a taxa de mora após a carência e soma a multa.', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(14)), child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: FilledButton.icon(onPressed: _simulate, icon: const Icon(Icons.visibility_rounded), label: const Text('Ver simulação'))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(onPressed: _clear, tooltip: 'Limpar', icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_showSimulation) ...[
          const SizedBox(height: 14),
          _SummaryCard(creditDate: _creditDate, interest: _interest!, payment: _payment!, total: _total!, rate: _effectiveRate!, installments: _plan.length, frequency: _frequencyLabel, note: _addNote ? _note.text : null),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Plano de Pagamentos', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  ..._plan.map((p) => _PaymentTile(row: p)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentRow {
  final int number;
  final DateTime due;
  final double capital;
  final double interest;
  final double total;
  const _PaymentRow({required this.number, required this.due, required this.capital, required this.interest, required this.total});
}

class _SummaryCard extends StatelessWidget {
  final DateTime creditDate;
  final double interest;
  final double payment;
  final double total;
  final double rate;
  final int installments;
  final String frequency;
  final String? note;
  const _SummaryCard({required this.creditDate, required this.interest, required this.payment, required this.total, required this.rate, required this.installments, required this.frequency, this.note});

  String money(double value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo do Crédito', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _line('Data do empréstimo', DateFormat('dd MMM. yyyy', 'pt_BR').format(creditDate).toUpperCase()),
            if (installments > 0) _line('Próxima data de pagamento', DateFormat('dd MMM. yyyy', 'pt_BR').format(creditDate.add(const Duration(days: 30))).toUpperCase()),
            _line('Data de vencimento do empréstimo', DateFormat('dd MMM. yyyy', 'pt_BR').format(creditDate.add(Duration(days: 30 * installments))).toUpperCase()),
            _line('Pagamentos em atraso', '0'),
            _line('Interesse', '${rate.toStringAsFixed(2)} %'),
            _line('Valor dos juros', money(interest)),
            _line('Parcelas pagas', '0/$installments'),
            _line('Frequência de Pagamento', frequency),
            _line('Valor do pagamento', money(payment)),
            _line('Montante total do empréstimo', money(total - interest)),
            _line('Empréstimo + juros', money(total)),
            _line('Total pago', money(0)),
            const Divider(height: 18),
            _line('Dívida de Capital', money(total - interest)),
            _line('Juros Pendentes', money(interest)),
            _line('Dívida total', money(total), bold: true),
            if (note != null && note!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)), child: Text('Nota: ${note!.trim()}')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(label)), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600))]),
      );
}

class _PaymentTile extends StatelessWidget {
  final _PaymentRow row;
  const _PaymentTile({required this.row});

  String money(double value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(child: Text('${row.number}')),
        title: Text('Parcela ${row.number.toString().padLeft(2, '0')}'),
        subtitle: Text('Capital ${money(row.capital)} • Juros ${money(row.interest)}\nVencimento ${DateFormat('dd MMM. yy', 'pt_BR').format(row.due)}'),
        trailing: Text(money(row.total), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
