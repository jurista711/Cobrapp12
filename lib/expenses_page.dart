import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/cobrapp_repository.dart';
import 'expenses_repository.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final repo = CobrAppRepository();
  final minValue = TextEditingController();
  final maxValue = TextEditingController();
  DateTime? from;
  DateTime? to;
  String? category;
  String? status;

  @override
  void dispose() {
    minValue.dispose();
    maxValue.dispose();
    super.dispose();
  }

  double? numberOf(String text) => double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
  String money(dynamic value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format((value as num?)?.toDouble() ?? 0);
  String dateText(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);
  }

  Future<void> chooseFrom() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: from ?? DateTime.now());
    if (picked != null) setState(() => from = picked);
  }

  Future<void> chooseTo() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: to ?? DateTime.now());
    if (picked != null) setState(() => to = picked);
  }

  Future<void> openForm([Map<String, dynamic>? row]) async {
    final description = TextEditingController(text: row?['description']?.toString() ?? '');
    final amount = TextEditingController(text: row == null ? '' : ((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2).replaceAll('.', ','));
    final notes = TextEditingController(text: row?['notes']?.toString() ?? '');
    var selectedCategory = row?['category']?.toString() ?? ExpensesRepository.categories.first;
    var selectedStatus = row?['status']?.toString() ?? 'paid';
    var date = DateTime.tryParse(row?['spent_at']?.toString() ?? '') ?? DateTime.now();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(row == null ? 'Criar despesa' : 'Editar despesa'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição da despesa', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                    items: ExpensesRepository.categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCategory = v ?? selectedCategory),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data de pagamento ou vencimento'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(date)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDate: date);
                      if (picked != null) setDialogState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Situação', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('Paga')),
                      DropdownMenuItem(value: 'pending', child: Text('Pendente')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observação', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final value = numberOf(amount.text);
                      if (description.text.trim().isEmpty || value == null || value <= 0) {
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Informe descrição e valor válido.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (row == null) {
                          await repo.createExpense(description: description.text, category: selectedCategory, amount: value, date: date, status: selectedStatus, notes: notes.text);
                        } else {
                          await repo.updateExpense(id: row['id'].toString(), description: description.text, category: selectedCategory, amount: value, date: date, status: selectedStatus, notes: notes.text);
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Erro ao salvar despesa: $e')));
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir despesa?'),
        content: Text('Deseja excluir "${row['description']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await repo.removeExpense(row['id'].toString());
    if (mounted) setState(() {});
  }

  void tutorial() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutorial de Controle de Despesas'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Toque em "Nova despesa" para registrar um gasto.\n\n'
            '2. Informe descrição, categoria, valor, data, situação Paga ou Pendente e observação quando necessário.\n\n'
            '3. Use os filtros por período, categoria, situação e valor para localizar despesas.\n\n'
            '4. Em cada despesa, use Editar para alterar os dados ou Excluir para removê-la.\n\n'
            '5. O resumo mostra o total do período, a média mensal e os valores agrupados por categoria.',
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: repo.expensesDetailed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Erro ao carregar despesas: ${snapshot.error}'));
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final report = repo.expenseReport(
          all,
          from: from,
          to: to,
          category: category,
          status: status,
          minValue: numberOf(minValue.text),
          maxValue: numberOf(maxValue.text),
        );
        final rows = List<Map<String, dynamic>>.from(report['rows'] as List);
        final byCategory = Map<String, double>.from(report['by_category'] as Map);
        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Controle de Despesas', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
                  IconButton(tooltip: 'Tutorial', onPressed: tutorial, icon: const Icon(Icons.help_outline)),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: () => openForm(), icon: const Icon(Icons.add), label: const Text('Nova despesa')),
                ],
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(onPressed: chooseFrom, icon: const Icon(Icons.date_range), label: Text(from == null ? 'Data inicial' : DateFormat('dd/MM/yyyy').format(from!))),
                      OutlinedButton.icon(onPressed: chooseTo, icon: const Icon(Icons.event), label: Text(to == null ? 'Data final' : DateFormat('dd/MM/yyyy').format(to!))),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String?>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                          items: [const DropdownMenuItem<String?>(value: null, child: Text('Todas')), ...ExpensesRepository.categories.map((e) => DropdownMenuItem<String?>(value: e, child: Text(e)))],
                          onChanged: (v) => setState(() => category = v),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String?>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Situação', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                            DropdownMenuItem<String?>(value: 'paid', child: Text('Paga')),
                            DropdownMenuItem<String?>(value: 'pending', child: Text('Pendente')),
                          ],
                          onChanged: (v) => setState(() => status = v),
                        ),
                      ),
                      SizedBox(width: 140, child: TextField(controller: minValue, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor mínimo', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
                      SizedBox(width: 140, child: TextField(controller: maxValue, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor máximo', border: OutlineInputBorder()), onChanged: (_) => setState(() {}))),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          from = null;
                          to = null;
                          category = null;
                          status = null;
                          minValue.clear();
                          maxValue.clear();
                        }),
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryCard(label: 'Total de despesas', value: money(report['total']), icon: Icons.payments_outlined),
                  _SummaryCard(label: 'Média mensal', value: money(report['monthly_average']), icon: Icons.calendar_month_outlined),
                  _SummaryCard(label: 'Registros', value: rows.length.toString(), icon: Icons.receipt_long_outlined),
                ],
              ),
              if (byCategory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Relatório por categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: byCategory.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(money(e.value), style: const TextStyle(fontWeight: FontWeight.w800)))).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Despesas cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Nenhuma despesa encontrada.'))))
              else
                for (final row in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(row['status'] == 'paid' ? Icons.check : Icons.schedule)),
                      title: Text(row['description']?.toString() ?? 'Despesa', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${row['category']} • ${dateText(row['spent_at'])} • ${row['status'] == 'paid' ? 'Paga' : 'Pendente'}${(row['notes']?.toString().trim().isNotEmpty ?? false) ? '\n${row['notes']}' : ''}'),
                      isThreeLine: row['notes']?.toString().trim().isNotEmpty ?? false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
                          IconButton(tooltip: 'Editar', onPressed: () => openForm(row), icon: const Icon(Icons.edit_outlined)),
                          IconButton(tooltip: 'Excluir', onPressed: () => remove(row), icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))])),
          ]),
        ),
      ),
    );
  }
}
