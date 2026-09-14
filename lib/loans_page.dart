import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/cobrapp_repository.dart';
import 'loans_repository.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final repo = CobrAppRepository();
  final search = TextEditingController();
  bool loading = true;
  String status = 'all';
  List<Map<String, dynamic>> loans = const [];

  @override
  void initState() {
    super.initState();
    _load();
    search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await repo.loansDetailed();
      if (mounted) setState(() => loans = rows);
    } catch (e) {
      if (mounted) _message('Não foi possível carregar os empréstimos: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filtered {
    final q = search.text.trim().toLowerCase();
    return loans.where((loan) {
      if (status != 'all' && loan['status']?.toString() != status) return false;
      if (q.isEmpty) return true;
      final customer = loan['cobrapp_customers'] as Map?;
      final values = [customer?['name'], loan['id'], loan['principal'], loan['total_amount'], loan['status']]
          .map((e) => e?.toString().toLowerCase() ?? '')
          .join(' ');
      return values.contains(q);
    }).toList();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _newLoan() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LoanFormPage(repo: repo)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Row(children: [
            const Expanded(child: Text('Empréstimos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            FilledButton.icon(onPressed: _newLoan, icon: const Icon(Icons.add), label: const Text('Novo')),
          ]),
          const SizedBox(height: 12),
          TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar por cliente, código ou valor')),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Todos'), selected: status == 'all', onSelected: (_) => setState(() => status = 'all')),
            ChoiceChip(label: const Text('Ativos'), selected: status == 'active', onSelected: (_) => setState(() => status = 'active')),
            ChoiceChip(label: const Text('Quitados'), selected: status == 'paid', onSelected: (_) => setState(() => status = 'paid')),
            ChoiceChip(label: const Text('Renegociados'), selected: status == 'renegotiated', onSelected: (_) => setState(() => status = 'renegotiated')),
          ]),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhum empréstimo encontrado.')))
          else
            ...filtered.map((loan) {
              final customer = loan['cobrapp_customers'] as Map?;
              final principal = (loan['principal'] as num?)?.toDouble() ?? 0;
              final total = (loan['total_amount'] as num?)?.toDouble() ?? 0;
              final currentStatus = loan['status']?.toString() ?? 'active';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_rounded)),
                  title: Text(customer?['name']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Capital: ${money.format(principal)}\nTotal: ${money.format(total)} • ${_statusLabel(currentStatus)}'),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => LoanDetailPage(repo: repo, loan: loan)),
                    );
                    if (changed == true) _load();
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

class LoanFormPage extends StatefulWidget {
  const LoanFormPage({super.key, required this.repo, this.oldLoan});
  final CobrAppRepository repo;
  final Map<String, dynamic>? oldLoan;

  @override
  State<LoanFormPage> createState() => _LoanFormPageState();
}

class _LoanFormPageState extends State<LoanFormPage> {
  final principal = TextEditingController();
  final rate = TextEditingController();
  final count = TextEditingController(text: '1');
  final note = TextEditingController();
  List<Map<String, dynamic>> customers = const [];
  Map<String, dynamic>? selectedCustomer;
  DateTime firstDueDate = DateTime.now().add(const Duration(days: 30));
  String paymentMethod = 'Dinheiro';
  String amortization = 'simple';
  bool lateEnabled = false;
  double lateRate = 0;
  double lateFeeBase = 0;
  LoanSimulation? simulation;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    principal.dispose(); rate.dispose(); count.dispose(); note.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final rows = await widget.repo.loanCustomers();
      final defaults = await widget.repo.loanDefaults();
      if (!mounted) return;
      setState(() {
        customers = rows;
        lateEnabled = defaults['late_interest_enabled'] == true;
        lateRate = (defaults['late_interest_rate'] as num?)?.toDouble() ?? 0;
        lateFeeBase = (defaults['late_fee_base'] as num?)?.toDouble() ?? 0;
        if (widget.oldLoan != null) {
          final old = widget.oldLoan!;
          for (final c in rows) {
            if (c['id'].toString() == old['customer_id'].toString()) {
              selectedCustomer = c;
              break;
            }
          }
          principal.text = _remainingFromEmbedded(old).toStringAsFixed(2);
          rate.text = ((old['interest_rate'] as num?)?.toDouble() ?? 0).toString();
          count.text = (old['installments'] ?? 1).toString();
          paymentMethod = old['default_payment_method']?.toString() ?? 'Dinheiro';
          amortization = old['amortization_method']?.toString() ?? 'simple';
          lateEnabled = old['late_interest_enabled'] == true;
          lateRate = (old['late_interest_rate'] as num?)?.toDouble() ?? lateRate;
          lateFeeBase = (old['late_fee_base'] as num?)?.toDouble() ?? lateFeeBase;
        }
      });
    } catch (e) {
      if (mounted) _msg('Erro ao preparar o formulário: $e');
    }
  }

  double _remainingFromEmbedded(Map<String, dynamic> loan) {
    final rows = (loan['cobrapp_installments'] as List?) ?? const [];
    return rows.fold<double>(0, (sum, row) {
      final m = row as Map;
      return sum + (((m['amount'] as num?)?.toDouble() ?? 0) - ((m['paid_amount'] as num?)?.toDouble() ?? 0));
    });
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _simulate() {
    final p = _num(principal); final r = _num(rate); final n = _int(count);
    if (selectedCustomer == null || p == null || r == null || n == null) {
      _msg('Selecione o cliente e preencha capital, taxa e parcelas.'); return;
    }
    try {
      setState(() {
        simulation = widget.repo.simulateLoan(principal: p, monthlyRate: r, installmentCount: n, firstDueDate: firstDueDate, amortizationMethod: amortization);
      });
    } catch (e) { _msg(e.toString()); }
  }

  Future<void> _save() async {
    final p = _num(principal); final r = _num(rate); final n = _int(count);
    if (selectedCustomer == null || p == null || r == null || n == null) {
      _msg('Selecione o cliente e preencha os campos obrigatórios.'); return;
    }
    _simulate();
    if (simulation == null) return;
    setState(() => saving = true);
    try {
      if (widget.oldLoan == null) {
        await widget.repo.createLoanDetailed(
          customerId: selectedCustomer!['id'].toString(), principal: p, monthlyRate: r, installmentCount: n,
          firstDueDate: firstDueDate, paymentMethod: paymentMethod, amortizationMethod: amortization,
          lateInterestEnabled: lateEnabled, lateInterestRate: lateRate, lateFeeBase: lateFeeBase,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        );
      } else {
        await widget.repo.renegotiateLoan(oldLoan: widget.oldLoan!, principal: p, monthlyRate: r, installmentCount: n, firstDueDate: firstDueDate, paymentMethod: paymentMethod, amortizationMethod: amortization);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _msg('Não foi possível salvar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Scaffold(
      appBar: AppBar(title: Text(widget.oldLoan == null ? 'Cadastrar empréstimo' : 'Renegociar empréstimo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: selectedCustomer,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: customers.map((c) => DropdownMenuItem(value: c, child: Text(c['name']?.toString() ?? 'Cliente'))).toList(),
            onChanged: widget.oldLoan == null ? (value) => setState(() => selectedCustomer = value) : null,
          ),
          const SizedBox(height: 10),
          TextField(controller: principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Capital emprestado', prefixText: 'R\$ ')),
          const SizedBox(height: 10),
          TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taxa de juros mensal (%)')),
          const SizedBox(height: 10),
          TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de parcelas')),
          const SizedBox(height: 10),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Primeiro vencimento'), subtitle: Text(DateFormat('dd/MM/yyyy').format(firstDueDate)), trailing: const Icon(Icons.calendar_month), onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: firstDueDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
            if (picked != null) setState(() => firstDueDate = picked);
          }),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            decoration: const InputDecoration(labelText: 'Forma de pagamento padrão'),
            items: const ['Dinheiro','Pix','Cartão de crédito','Cartão de débito','Cheque','Transferência'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => paymentMethod = v ?? 'Dinheiro'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: amortization,
            decoration: const InputDecoration(labelText: 'Sistema de cálculo'),
            items: const [DropdownMenuItem(value: 'simple', child: Text('Juros simples')), DropdownMenuItem(value: 'price', child: Text('Tabela Price'))],
            onChanged: (v) => setState(() { amortization = v ?? 'simple'; simulation = null; }),
          ),
          const SizedBox(height: 10),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Ativar juros de mora'), value: lateEnabled, onChanged: (v) => setState(() => lateEnabled = v)),
          if (lateEnabled) ...[
            TextFormField(initialValue: lateRate.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Juros de mora mensal (%)'), onChanged: (v) => lateRate = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            const SizedBox(height: 10),
            TextFormField(initialValue: lateFeeBase.toString(), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Base da multa por atraso', prefixText: 'R\$ '), onChanged: (v) => lateFeeBase = double.tryParse(v.replaceAll(',', '.')) ?? 0),
          ],
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
          const SizedBox(height: 14),
          OutlinedButton.icon(onPressed: _simulate, icon: const Icon(Icons.calculate), label: const Text('Simular empréstimo')),
          if (simulation != null) ...[
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Simulação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Parcela: ${money.format(simulation!.installment)}'),
              Text('Juros totais: ${money.format(simulation!.totalInterest)}'),
              Text('Custo total: ${money.format(simulation!.total)}'),
              const Divider(),
              ...simulation!.rows.map((row) => Text('${row.number}ª • ${DateFormat('dd/MM/yyyy').format(row.dueDate)} • ${money.format(row.amount)}')),
            ]))),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
            label: Text(widget.oldLoan == null ? 'Confirmar empréstimo' : 'Confirmar renegociação'),
          ),
        ],
      ),
    );
  }
}

class LoanDetailPage extends StatefulWidget {
  const LoanDetailPage({super.key, required this.repo, required this.loan});
  final CobrAppRepository repo;
  final Map<String, dynamic> loan;

  @override
  State<LoanDetailPage> createState() => _LoanDetailPageState();
}

class _LoanDetailPageState extends State<LoanDetailPage> {
  late Map<String, dynamic> loan;
  List<Map<String, dynamic>> installments = const [];
  bool loading = true;

  @override
  void initState() { super.initState(); loan = Map<String, dynamic>.from(widget.loan); _reload(); }

  Future<void> _reload() async {
    setState(() => loading = true);
    try {
      installments = await widget.repo.installments(loanId: loan['id'].toString());
      final all = await widget.repo.loansDetailed();
      for (final e in all) { if (e['id'].toString() == loan['id'].toString()) { loan = e; break; } }
    } catch (e) { if (mounted) _msg('Erro ao atualizar empréstimo: $e'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  double get remaining => installments.where((e) => e['status'] != 'paid').fold<double>(0, (sum, e) => sum + (((e['amount'] as num?)?.toDouble() ?? 0) - ((e['paid_amount'] as num?)?.toDouble() ?? 0)));

  Future<double?> _askNumber(String title, {double initial = 0}) async {
    final c = TextEditingController(text: initial.toStringAsFixed(2));
    final result = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))), child: const Text('Confirmar'))],
    ));
    c.dispose(); return result;
  }

  Future<void> _addInstallment() async {
    final amount = await _askNumber('Valor da nova parcela'); if (amount == null || amount <= 0) return;
    if (!mounted) return;
    final due = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (due == null) return;
    await widget.repo.addInstallmentToLoan(loan: loan, amount: amount, dueDate: due);
    _msg('Parcela adicionada.'); await _reload();
  }

  Future<void> _lateInterest() async {
    final rate = await _askNumber('Taxa de juros de mora (%)', initial: (loan['late_interest_rate'] as num?)?.toDouble() ?? 0);
    if (rate == null || rate < 0) return;
    await widget.repo.setLoanLateInterest(loanId: loan['id'].toString(), enabled: true, rate: rate);
    _msg('Juros de mora ativados/atualizados.'); await _reload();
  }

  Future<void> _disableLateInterest() async {
    await widget.repo.setLoanLateInterest(loanId: loan['id'].toString(), enabled: false, rate: (loan['late_interest_rate'] as num?)?.toDouble() ?? 0);
    _msg('Juros de mora desativados.'); await _reload();
  }

  Future<void> _lateFee() async {
    final base = await _askNumber('Atualizar base da multa', initial: (loan['late_fee_base'] as num?)?.toDouble() ?? 0);
    if (base == null || base < 0) return;
    await widget.repo.updateLateFeeBase(loanId: loan['id'].toString(), base: base);
    _msg('Base da multa atualizada.'); await _reload();
  }

  Future<void> _anticipate(Map<String, dynamic> installment) async {
    final discount = await _askNumber('Desconto para antecipação (%)');
    if (discount == null || discount < 0 || discount > 100) return;
    final net = await widget.repo.anticipateInstallment(loan: loan, installment: installment, discountPercent: discount);
    _msg('Parcela antecipada por ${_money(net)}.'); await _reload();
  }

  Future<void> _liquidate() async {
    final discount = await _askNumber('Desconto para liquidação (%)');
    if (discount == null || discount < 0 || discount > 100 || !mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Liquidar empréstimo'), content: Text('Saldo atual: ${_money(remaining)}.\nDeseja quitar todo o saldo restante?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Liquidar'))],
    ));
    if (ok != true) return;
    final paid = await widget.repo.liquidateLoan(loan: loan, discountPercent: discount);
    _msg('Empréstimo liquidado por ${_money(paid)}.'); await _reload();
  }

  Future<void> _commitment() async {
    final amount = await _askNumber('Valor do compromisso'); if (amount == null || amount <= 0 || !mounted) return;
    final date = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Compromisso de pagamento'), content: TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Observações')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar'))],
    ));
    if (confirmed == true) {
      await widget.repo.setPaymentCommitment(loanId: loan['id'].toString(), date: date, amount: amount, notes: notes.text.trim().isEmpty ? null : notes.text.trim());
      _msg('Compromisso de pagamento registrado.'); await _reload();
    }
    notes.dispose();
  }

  void _contract() {
    final customer = loan['cobrapp_customers'] as Map?;
    final created = DateTime.tryParse(loan['created_at']?.toString() ?? '');
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Contrato de Mútuo'),
      content: SingleChildScrollView(child: SelectableText(
        'CONTRATO DE MÚTUO\n\nMutuante: empresa cadastrada no Roots Cobrança.\nMutuário: ${customer?['name'] ?? 'Cliente'}${customer?['document'] == null ? '' : ' — ${customer?['document']}'}.'
        '\n\nCapital emprestado: ${_money((loan['principal'] as num?)?.toDouble() ?? 0)}.\nTaxa de juros: ${loan['interest_rate'] ?? 0}% ao mês.\nNúmero de parcelas: ${loan['installments']}.\nValor total: ${_money((loan['total_amount'] as num?)?.toDouble() ?? 0)}.\nData do contrato: ${created == null ? '-' : DateFormat('dd/MM/yyyy').format(created)}.'
        '\n\nAs partes reconhecem as condições acima e o cronograma de parcelas registrado no sistema.'
      )),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
    ));
  }

  String _money(double value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);

  @override
  Widget build(BuildContext context) {
    final customer = loan['cobrapp_customers'] as Map?;
    final commitmentDate = loan['commitment_date']?.toString();
    return Scaffold(
      appBar: AppBar(title: Text(customer?['name']?.toString() ?? 'Empréstimo')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Status: ${_statusLabel(loan['status']?.toString() ?? 'active')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Capital: ${_money((loan['principal'] as num?)?.toDouble() ?? 0)}'),
              Text('Total: ${_money((loan['total_amount'] as num?)?.toDouble() ?? 0)}'),
              Text('Saldo: ${_money(remaining)}'),
              Text('Taxa: ${loan['interest_rate'] ?? 0}% ao mês'),
              Text('Parcelas: ${loan['installments']}'),
              if (commitmentDate != null) Text('Compromisso: ${loan['commitment_amount'] == null ? '' : _money((loan['commitment_amount'] as num).toDouble())} em ${DateFormat('dd/MM/yyyy').format(DateTime.parse(commitmentDate))}'),
            ]))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _addInstallment, icon: const Icon(Icons.add), label: const Text('Adicionar parcela')),
              OutlinedButton.icon(onPressed: loan['late_interest_enabled'] == true ? _disableLateInterest : _lateInterest, icon: const Icon(Icons.percent), label: Text(loan['late_interest_enabled'] == true ? 'Desativar mora' : 'Ativar mora')),
              OutlinedButton.icon(onPressed: _lateInterest, icon: const Icon(Icons.calculate), label: const Text('Taxa de mora')),
              OutlinedButton.icon(onPressed: _lateFee, icon: const Icon(Icons.warning_amber), label: const Text('Base da multa')),
              OutlinedButton.icon(onPressed: loan['status'] == 'paid' ? null : () async {
                final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LoanFormPage(repo: widget.repo, oldLoan: loan)));
                if (changed == true && mounted) Navigator.of(context).pop(true);
              }, icon: const Icon(Icons.sync_alt), label: const Text('Renegociar')),
              OutlinedButton.icon(onPressed: loan['status'] == 'paid' ? null : _liquidate, icon: const Icon(Icons.done_all), label: const Text('Liquidar')),
              OutlinedButton.icon(onPressed: _contract, icon: const Icon(Icons.description), label: const Text('Contrato de Mútuo')),
              OutlinedButton.icon(onPressed: loan['status'] == 'paid' ? null : _commitment, icon: const Icon(Icons.event_available), label: const Text('Compromisso')),
            ]),
            const SizedBox(height: 14),
            const Text('Parcelas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (loading) const Center(child: CircularProgressIndicator()) else ...installments.map((installment) {
              final due = DateTime.tryParse(installment['due_date']?.toString() ?? '');
              final mora = widget.repo.overdueInterestFor(loan: loan, installment: installment);
              final fee = widget.repo.lateFeeFor(loan: loan, installment: installment);
              final paid = (installment['paid_amount'] as num?)?.toDouble() ?? 0;
              final amount = (installment['amount'] as num?)?.toDouble() ?? 0;
              final st = installment['status']?.toString() ?? 'pending';
              return Card(child: ListTile(
                title: Text('${installment['number']}ª parcela • ${_money(amount)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Vencimento: ${due == null ? '-' : DateFormat('dd/MM/yyyy').format(due)}\nPago: ${_money(paid)} • ${_installmentStatus(st, due)}${mora > 0 ? '\nJuros de mora: ${_money(mora)}' : ''}${fee > 0 ? '\nMulta: ${_money(fee)}' : ''}'),
                isThreeLine: true,
                trailing: st == 'paid' ? const Icon(Icons.check_circle, color: Colors.green) : IconButton(tooltip: 'Antecipar pagamento', onPressed: () => _anticipate(installment), icon: const Icon(Icons.fast_forward)),
              ));
            }),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) { case 'paid': return 'Quitado'; case 'renegotiated': return 'Renegociado'; case 'overdue': return 'Vencido'; default: return 'Ativo'; }
}

String _installmentStatus(String status, DateTime? due) {
  if (status == 'paid') return 'Paga';
  if (status == 'renegotiated') return 'Renegociada';
  if (status == 'partial') return 'Parcial';
  if (due != null && due.isBefore(DateTime.now())) return 'Vencida';
  return 'A vencer';
}
