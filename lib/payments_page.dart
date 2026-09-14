import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'data/cobrapp_repository.dart';
import 'payments_repository.dart';

String _money(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(n);
}

String _date(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '');
  return d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);
}

Map<String, dynamic>? _rel(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final repo = CobrAppRepository();
  final search = TextEditingController();
  List<Map<String, dynamic>> history = const [];
  List<Map<String, dynamic>> customers = const [];
  List<String> methods = const [];
  bool loading = true;
  String? customerFilter;
  String? methodFilter;
  String? registrarFilter;
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        repo.paymentHistoryDetailed(),
        repo.paymentCustomers(),
        repo.paymentMethods(),
      ]);
      if (!mounted) return;
      setState(() {
        history = values[0] as List<Map<String, dynamic>>;
        customers = values[1] as List<Map<String, dynamic>>;
        methods = values[2] as List<String>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar pagamentos: $e')));
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = search.text.trim().toLowerCase();
    return history.where((row) {
      final customer = _rel(row['cobrapp_customers']);
      final name = customer?['name']?.toString() ?? '';
      if (customerFilter != null && row['customer_id']?.toString() != customerFilter) return false;
      if (methodFilter != null && row['method']?.toString() != methodFilter) return false;
      if (registrarFilter != null && row['registered_by_email']?.toString() != registrarFilter) return false;
      final paidAt = DateTime.tryParse(row['paid_at']?.toString() ?? '');
      if (from != null && paidAt != null && paidAt.isBefore(DateTime(from!.year, from!.month, from!.day))) return false;
      if (to != null && paidAt != null && paidAt.isAfter(DateTime(to!.year, to!.month, to!.day, 23, 59, 59))) return false;
      if (q.isEmpty) return true;
      final amount = row['amount']?.toString() ?? '';
      final date = row['paid_at']?.toString() ?? '';
      return name.toLowerCase().contains(q) || amount.toLowerCase().contains(q) || date.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get registrars {
    final values = history
        .map((e) => e['registered_by_email']?.toString())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  Future<void> _register() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PaymentFormDialog(),
    );
    if (result == null) return;
    await _load();
    if (!mounted) return;
    final credit = (result['credit'] as num?)?.toDouble() ?? 0;
    final balance = (result['remaining_balance'] as num?)?.toDouble() ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(credit > 0
            ? 'Pagamento registrado. Crédito para parcelas futuras: ${_money(credit)}.'
            : 'Pagamento registrado. Saldo devedor: ${_money(balance)}.'),
      ),
    );
    if (result['generate_receipt'] == true) {
      await _generateReceipt(result);
    }
  }

  Future<void> _generateReceipt(Map<String, dynamic> result) async {
    final paymentId = result['first_payment_id']?.toString();
    final customerId = result['customer_id']?.toString();
    if (paymentId == null || customerId == null) return;
    final amount = (result['amount_received'] as num?)?.toDouble() ?? 0;
    final customerName = result['customer_name']?.toString() ?? 'Cliente';
    final method = result['method']?.toString() ?? '';
    final paidAt = result['paid_at']?.toString() ?? '';
    final text = 'Recebemos de $customerName o valor de ${_money(amount)}, em ${_date(paidAt)}, por $method.';
    final receipt = await repo.createReceipt(paymentId: paymentId, customerId: customerId, amount: amount, text: text);
    final number = receipt['receipt_number']?.toString() ?? '';
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (_) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('RECIBO / COMPROVANTE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Recibo nº $number'),
              pw.SizedBox(height: 24),
              pw.Text(text, style: const pw.TextStyle(fontSize: 13)),
              pw.SizedBox(height: 12),
              pw.Text('Valor: ${_money(amount)}'),
              pw.Text('Forma de pagamento: $method'),
              pw.Text('Data: ${_date(paidAt)}'),
              pw.Spacer(),
              pw.Row(children: [pw.Expanded(child: pw.Divider()), pw.SizedBox(width: 20), pw.Expanded(child: pw.Divider())]),
              pw.Row(children: [pw.Expanded(child: pw.Center(child: pw.Text('Assinatura da empresa'))), pw.SizedBox(width: 20), pw.Expanded(child: pw.Center(child: pw.Text('Assinatura do cliente')))]),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf.save(), name: 'recibo-$number.pdf');
  }

  Future<void> _statement() async {
    await showDialog<void>(context: context, builder: (_) => _StatementDialog(customers: customers));
  }

  Future<void> _promise() async {
    final changed = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _PromiseDialog(customers: customers));
    if (changed == true) await _load();
  }

  Future<void> _pickRange(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (from ?? DateTime.now()) : (to ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => isFrom ? from = picked : to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final rows = filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(onPressed: _register, icon: const Icon(Icons.add_card), label: const Text('Registrar Pagamento')),
              OutlinedButton.icon(onPressed: _statement, icon: const Icon(Icons.receipt_long), label: const Text('Extrato de Conta')),
              OutlinedButton.icon(onPressed: _promise, icon: const Icon(Icons.event_available), label: const Text('Data de Pagamento Prometida')),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: search,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar por nome, valor ou data', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String?>(
                  initialValue: customerFilter,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  items: [const DropdownMenuItem(value: null, child: Text('Todos')), ...customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Cliente')))],
                  onChanged: (v) => setState(() => customerFilter = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: methodFilter,
                  decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                  items: [const DropdownMenuItem(value: null, child: Text('Todas')), ...methods.map((m) => DropdownMenuItem(value: m, child: Text(m)))],
                  onChanged: (v) => setState(() => methodFilter = v),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String?>(
                  initialValue: registrarFilter,
                  decoration: const InputDecoration(labelText: 'Usuário que registrou'),
                  items: [const DropdownMenuItem(value: null, child: Text('Todos')), ...registrars.map((m) => DropdownMenuItem(value: m, child: Text(m)))],
                  onChanged: (v) => setState(() => registrarFilter = v),
                ),
              ),
              OutlinedButton(onPressed: () => _pickRange(true), child: Text(from == null ? 'Período inicial' : _date(from!.toIso8601String()))),
              OutlinedButton(onPressed: () => _pickRange(false), child: Text(to == null ? 'Período final' : _date(to!.toIso8601String()))),
            ],
          ),
          const SizedBox(height: 16),
          Text('Histórico de Pagamentos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (loading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhum pagamento encontrado.')))
          else
            ...rows.map((row) {
              final customer = _rel(row['cobrapp_customers']);
              final installment = _rel(row['cobrapp_installments']);
              final who = row['registered_by_email']?.toString() ?? row['registered_by']?.toString() ?? '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
                  title: Text('${customer?['name'] ?? 'Cliente'} • ${_money(row['amount'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${_date(row['paid_at'])} • ${row['method'] ?? '-'} • ${installment == null ? (row['type'] == 'credit' ? 'Crédito' : '-') : 'Parcela ${installment['number']}'}\nRegistrado por: $who'),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PaymentFormDialog extends StatefulWidget {
  const _PaymentFormDialog();

  @override
  State<_PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends State<_PaymentFormDialog> {
  final repo = CobrAppRepository();
  final amount = TextEditingController();
  final notes = TextEditingController();
  List<Map<String, dynamic>> customers = const [];
  List<Map<String, dynamic>> loans = const [];
  List<Map<String, dynamic>> installments = const [];
  List<String> methods = const [];
  final selected = <String>{};
  String? customerId;
  String? loanId;
  String? method;
  DateTime paidAt = DateTime.now();
  bool automatic = true;
  bool generateReceipt = true;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final values = await Future.wait([repo.paymentCustomers(), repo.paymentMethods()]);
    if (!mounted) return;
    setState(() {
      customers = values[0] as List<Map<String, dynamic>>;
      methods = values[1] as List<String>;
      method = methods.isEmpty ? null : methods.first;
      loading = false;
    });
  }

  Future<void> _customer(String? id) async {
    setState(() {
      customerId = id;
      loanId = null;
      loans = const [];
      installments = const [];
      selected.clear();
    });
    if (id == null) return;
    final value = await repo.activeLoansForPayment(id);
    if (mounted) setState(() => loans = value);
  }

  Future<void> _loan(String? id) async {
    setState(() {
      loanId = id;
      installments = const [];
      selected.clear();
    });
    if (id == null) return;
    final value = await repo.openInstallmentsForPayment(id);
    if (mounted) setState(() => installments = value);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(context: context, initialDate: paidAt, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (value != null) setState(() => paidAt = value);
  }

  Future<void> _save() async {
    final value = double.tryParse(amount.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (customerId == null || loanId == null || value == null || value <= 0 || method == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha cliente, empréstimo, valor e forma de pagamento.')));
      return;
    }
    if (!automatic && selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos uma parcela.')));
      return;
    }
    setState(() => saving = true);
    try {
      final result = await repo.registerPayment(
        customerId: customerId!,
        loanId: loanId!,
        installmentIds: selected.toList(),
        amount: value,
        method: method!,
        paidAt: paidAt,
        automatic: automatic,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
      final customer = customers.firstWhere((c) => c['id'].toString() == customerId);
      if (!mounted) return;
      Navigator.of(context).pop({
        ...result,
        'customer_id': customerId,
        'customer_name': customer['name'],
        'method': method,
        'paid_at': paidAt.toIso8601String(),
        'generate_receipt': generateReceipt,
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível registrar: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Pagamento'),
      content: SizedBox(
        width: 620,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: customerId,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Cliente'))).toList(),
                      onChanged: _customer,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: loanId,
                      decoration: const InputDecoration(labelText: 'Empréstimo ativo'),
                      items: loans.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text('${_money(l['principal'])} • ${l['status']}'))).toList(),
                      onChanged: _loan,
                    ),
                    SwitchListTile(
                      value: automatic,
                      onChanged: (v) => setState(() => automatic = v),
                      title: const Text('Aplicar Pagamento a Parcela automaticamente'),
                      subtitle: Text(automatic ? 'Aplica em parcelas abertas na ordem de vencimento.' : 'Seleção manual das parcelas.'),
                    ),
                    if (!automatic && installments.isNotEmpty)
                      ...installments.map((i) {
                        final id = i['id'].toString();
                        final due = repo.outstandingAmount(i);
                        return CheckboxListTile(
                          dense: true,
                          value: selected.contains(id),
                          onChanged: (v) => setState(() => v == true ? selected.add(id) : selected.remove(id)),
                          title: Text('Parcela ${i['number']} • ${_date(i['due_date'])}'),
                          subtitle: Text('Saldo: ${_money(due)}'),
                        );
                      }),
                    const SizedBox(height: 8),
                    TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor pago', prefixText: 'R\$ ')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
                      items: methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => method = v),
                    ),
                    const SizedBox(height: 10),
                    ListTile(contentPadding: EdgeInsets.zero, title: const Text('Data do pagamento'), subtitle: Text(_date(paidAt.toIso8601String())), trailing: const Icon(Icons.calendar_month), onTap: _pickDate),
                    TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: generateReceipt,
                      onChanged: (v) => setState(() => generateReceipt = v ?? true),
                      title: const Text('Gerar Recibo/Comprovante'),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Salvando...' : 'Confirmar Pagamento')),
      ],
    );
  }
}

class _StatementDialog extends StatefulWidget {
  const _StatementDialog({required this.customers});
  final List<Map<String, dynamic>> customers;

  @override
  State<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends State<_StatementDialog> {
  final repo = CobrAppRepository();
  String? customerId;
  List<Map<String, dynamic>> events = const [];
  double credit = 0;
  bool loading = false;

  Future<void> _load(String? id) async {
    setState(() {
      customerId = id;
      events = const [];
      credit = 0;
      loading = id != null;
    });
    if (id == null) return;
    final values = await Future.wait([repo.accountStatement(id), repo.customerCredit(id)]);
    if (!mounted) return;
    setState(() {
      events = values[0] as List<Map<String, dynamic>>;
      credit = values[1] as double;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extrato de Conta'),
      content: SizedBox(
        width: 700,
        height: 520,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: customerId,
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: widget.customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Cliente'))).toList(),
              onChanged: _load,
            ),
            if (customerId != null) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Align(alignment: Alignment.centerLeft, child: Text('Crédito disponível: ${_money(credit)}', style: const TextStyle(fontWeight: FontWeight.w800)))),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (_, index) {
                        final e = events[index];
                        final extras = <String>[];
                        if (((e['late_interest'] as num?)?.toDouble() ?? 0) > 0) extras.add('Juros de mora ${_money(e['late_interest'])}');
                        if (((e['late_fee'] as num?)?.toDouble() ?? 0) > 0) extras.add('Multa ${_money(e['late_fee'])}');
                        if (((e['credit'] as num?)?.toDouble() ?? 0) > 0) extras.add('Crédito ${_money(e['credit'])}');
                        return ListTile(
                          title: Text('${e['kind']} • ${_money(e['amount'])}'),
                          subtitle: Text('${_date(e['date'])} • ${e['description']}${extras.isEmpty ? '' : '\n${extras.join(' • ')}'}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
    );
  }
}

class _PromiseDialog extends StatefulWidget {
  const _PromiseDialog({required this.customers});
  final List<Map<String, dynamic>> customers;

  @override
  State<_PromiseDialog> createState() => _PromiseDialogState();
}

class _PromiseDialogState extends State<_PromiseDialog> {
  final repo = CobrAppRepository();
  final amount = TextEditingController();
  final notes = TextEditingController();
  List<Map<String, dynamic>> loans = const [];
  String? customerId;
  String? loanId;
  DateTime date = DateTime.now();
  bool saving = false;

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _customer(String? id) async {
    setState(() {
      customerId = id;
      loanId = null;
      loans = const [];
    });
    if (id == null) return;
    final value = await repo.activeLoansForPayment(id);
    if (mounted) setState(() => loans = value);
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (value != null) setState(() => date = value);
  }

  Future<void> _save() async {
    final value = double.tryParse(amount.text.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (loanId == null || value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione o empréstimo e informe o valor prometido.')));
      return;
    }
    setState(() => saving = true);
    try {
      await repo.setPromisedPaymentDate(loanId: loanId!, date: date, amount: value, notes: notes.text.trim().isEmpty ? null : notes.text.trim());
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Data de Pagamento Prometida'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: customerId,
              decoration: const InputDecoration(labelText: 'Cliente'),
              items: widget.customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? 'Cliente'))).toList(),
              onChanged: _customer,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: loanId,
              decoration: const InputDecoration(labelText: 'Empréstimo'),
              items: loans.map((l) => DropdownMenuItem(value: l['id'].toString(), child: Text('${_money(l['principal'])} • ${l['status']}'))).toList(),
              onChanged: (v) => setState(() => loanId = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor prometido', prefixText: 'R\$ ')),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Data prometida'), subtitle: Text(_date(date.toIso8601String())), trailing: const Icon(Icons.calendar_month), onTap: _pickDate),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observação')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Salvando...' : 'Salvar')),
      ],
    );
  }
}
