import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'reports_repository.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _repo = ReportsRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.load();
  }

  String money(num? value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value ?? 0);
  String dateText(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null ? '-' : DateFormat('dd/MM/yyyy').format(d);
  }

  void reload() => setState(() => _future = _repo.load());

  List<xls.CellValue?> excelRow(List<Object?> values) => values
      .map<xls.CellValue?>((value) => xls.TextCellValue(value?.toString() ?? ''))
      .toList();

  Future<void> exportExcel(Map<String, dynamic> data) async {
    final rows = List<Map<String, dynamic>>.from(data['detailed_loans'] as List? ?? const []);
    final excel = xls.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Carteira') excel.rename(defaultSheet, 'Carteira');
    final sheet = excel['Carteira'];
    sheet.appendRow(excelRow(['ID', 'Cliente', 'Capital', 'Total', 'Recebido', 'Em aberto', 'Status', 'Vencido', 'Data']));
    for (final row in rows) {
      sheet.appendRow(excelRow([
        row['id'], row['customer'], row['principal'], row['total'], row['received'], row['pending'], row['status'],
        row['overdue'] == true ? 'Sim' : 'Não', dateText(row['created_at']),
      ]));
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/roots_carteira_completa.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Carteira completa - Roots Cobrança'));
  }

  String csvValue(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> exportCsv(Map<String, dynamic> data) async {
    final rows = List<Map<String, dynamic>>.from(data['detailed_loans'] as List? ?? const []);
    final out = StringBuffer();
    out.writeln(['ID','Cliente','Capital','Total','Recebido','Em aberto','Status','Vencido','Data'].map(csvValue).join(','));
    for (final row in rows) {
      out.writeln([
        row['id'], row['customer'], row['principal'], row['total'], row['received'], row['pending'], row['status'],
        row['overdue'] == true ? 'Sim' : 'Não', dateText(row['created_at']),
      ].map(csvValue).join(','));
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/roots_carteira_completa.csv');
    await file.writeAsBytes(utf8.encode('\uFEFF${out.toString()}'), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Carteira completa - Roots Cobrança'));
  }

  Widget metricCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ])),
        ]),
      ),
    );
  }

  Widget premiumBlock(String title, Widget child) {
    if (_repo.hasPremiumAccess) return child;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Funcionalidade Premium'),
          ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
        final data = snapshot.data ?? <String, dynamic>{};
        final status = Map<String, dynamic>.from(data['status'] as Map? ?? const {});
        final metrics = Map<String, dynamic>.from(data['metrics'] as Map? ?? const {});
        final detailed = List<Map<String, dynamic>>.from(data['detailed_loans'] as List? ?? const []);
        final perDay = Map<String, int>.from(data['customers_per_day'] as Map? ?? const {});
        final top = List<Map<String, dynamic>>.from(data['top_customers'] as List? ?? const []);
        final perDayEntries = perDay.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(children: [
                const Expanded(child: Text('Relatórios e Exportações', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
              ]),
              const SizedBox(height: 12),
              const Text('Relatório de Status de Negócios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.15,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  metricCard('Ativos', '${status['active'] ?? 0}', Icons.play_circle_outline),
                  metricCard('Quitados', '${status['paid'] ?? 0}', Icons.check_circle_outline),
                  metricCard('Vencidos', '${status['overdue'] ?? 0}', Icons.warning_amber_rounded),
                  metricCard('Renegociados', '${status['renegotiated'] ?? 0}', Icons.sync_alt_rounded),
                ],
              ),
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: Text('Exportar Carteira Completa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                OutlinedButton.icon(onPressed: () => exportCsv(data), icon: const Icon(Icons.table_view_rounded), label: const Text('CSV')),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: () => exportExcel(data), icon: const Icon(Icons.grid_on_rounded), label: const Text('Excel')),
              ]),
              const SizedBox(height: 18),
              premiumBlock(
                'Análise Completa da Carteira',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Análise Completa da Carteira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.05,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      metricCard('Capital emprestado', money(metrics['loaned'] as num?), Icons.account_balance_wallet_outlined),
                      metricCard('Total recebido', money(metrics['received'] as num?), Icons.payments_outlined),
                      metricCard('Saldo em aberto', money(metrics['pending'] as num?), Icons.hourglass_bottom_rounded),
                      metricCard('Valor em atraso', money(metrics['overdue'] as num?), Icons.error_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...detailed.take(50).map((row) => Card(
                    child: ListTile(
                      title: Text(row['customer']?.toString() ?? 'Cliente'),
                      subtitle: Text('${dateText(row['created_at'])} • ${row['status']}'),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(money(row['principal'] as num?), style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('Em aberto: ${money(row['pending'] as num?)}', style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  )),
                ]),
              ),
              const SizedBox(height: 18),
              premiumBlock(
                'Relatórios Avançados',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Relatórios Avançados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.05,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      metricCard('Ticket médio', money(metrics['average_ticket'] as num?), Icons.analytics_outlined),
                      metricCard('Inadimplência', '${((metrics['delinquency_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%', Icons.trending_down_rounded),
                      metricCard('Recuperação', '${((metrics['recovery_percent'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%', Icons.trending_up_rounded),
                      metricCard('Em atraso', money(metrics['overdue'] as num?), Icons.report_problem_outlined),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const Text('Clientes por Dia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (perDayEntries.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum cadastro encontrado.')))
              else
                ...perDayEntries.take(31).map((entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(dateText(entry.key)),
                    trailing: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                )),
              const SizedBox(height: 18),
              const Text('Clientes que Mais Pagaram', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (top.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Nenhum pagamento encontrado.')))
              else
                ...top.take(20).toList().asMap().entries.map((entry) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${entry.key + 1}')),
                    title: Text(entry.value['name']?.toString() ?? 'Cliente'),
                    trailing: Text(money(entry.value['total_paid'] as num?), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}
