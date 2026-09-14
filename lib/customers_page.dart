import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xls;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'customers_repository.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final repo = CustomersRepository();
  final searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> future;

  String filter = 'ativos';
  String order = 'nome';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = repo.allCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reload() {
    setState(() => future = repo.allCustomers());
  }

  String fullName(Map<String, dynamic> row) {
    return [
      row['name']?.toString() ?? '',
      row['last_name']?.toString() ?? '',
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();
  }

  List<Map<String, dynamic>> filtered(List<Map<String, dynamic>> rows) {
    final query = searchController.text.trim().toLowerCase();
    var result = rows.where((row) {
      final active = row['is_active'] != false;
      if (filter == 'ativos' && !active) return false;
      if ((filter == 'inativos' || filter == 'reativaveis') && active) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        fullName(row),
        row['document'],
        row['phone'],
        row['landline'],
        row['email'],
        row['address'],
      ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();

    if (order == 'cadastro') {
      result.sort((a, b) {
        final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    } else {
      result.sort(
        (a, b) => fullName(a).toLowerCase().compareTo(fullName(b).toLowerCase()),
      );
    }
    return result;
  }

  Future<void> customerForm({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final lastName =
        TextEditingController(text: existing?['last_name']?.toString() ?? '');
    final document =
        TextEditingController(text: existing?['document']?.toString() ?? '');
    final address =
        TextEditingController(text: existing?['address']?.toString() ?? '');
    final phone =
        TextEditingController(text: existing?['phone']?.toString() ?? '');
    final landline =
        TextEditingController(text: existing?['landline']?.toString() ?? '');
    final email =
        TextEditingController(text: existing?['email']?.toString() ?? '');
    final notes =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
    final tags = TextEditingController(
      text: ((existing?['tags'] as List?) ?? const []).join(', '),
    );
    final coDebtorName =
        TextEditingController(text: existing?['co_debtor_name']?.toString() ?? '');
    final coDebtorDocument = TextEditingController(
      text: existing?['co_debtor_document']?.toString() ?? '',
    );
    final coDebtorPhone = TextEditingController(
      text: existing?['co_debtor_phone']?.toString() ?? '',
    );
    final referenceName = TextEditingController(
      text: existing?['reference1_name']?.toString() ?? '',
    );
    final referenceRelation = TextEditingController(
      text: existing?['reference1_relation']?.toString() ?? '',
    );
    final referencePhone = TextEditingController(
      text: existing?['reference1_phone']?.toString() ?? '',
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Adicionar Cliente' : 'Editar Cliente'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nome'),
                  ),
                  TextField(
                    controller: lastName,
                    decoration: const InputDecoration(labelText: 'Sobrenome'),
                  ),
                  TextField(
                    controller: document,
                    decoration: const InputDecoration(labelText: 'CPF/CNPJ'),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Endereço'),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefone'),
                  ),
                  TextField(
                    controller: landline,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefone fixo'),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Etiquetas',
                      hintText: 'Separadas por vírgula',
                    ),
                  ),
                  TextField(
                    controller: coDebtorName,
                    decoration: const InputDecoration(labelText: 'Codevedor'),
                  ),
                  TextField(
                    controller: coDebtorDocument,
                    decoration: const InputDecoration(
                      labelText: 'CPF/CNPJ do codevedor',
                    ),
                  ),
                  TextField(
                    controller: coDebtorPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefone do codevedor',
                    ),
                  ),
                  TextField(
                    controller: referenceName,
                    decoration: const InputDecoration(
                      labelText: 'Referência - nome',
                    ),
                  ),
                  TextField(
                    controller: referenceRelation,
                    decoration: const InputDecoration(
                      labelText: 'Referência - relação',
                    ),
                  ),
                  TextField(
                    controller: referencePhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Referência - telefone',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Observações'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Informe o nome do cliente.')),
                  );
                  return;
                }
                final values = <String, dynamic>{
                  'name': name.text,
                  'last_name': lastName.text,
                  'document': document.text,
                  'address': address.text,
                  'phone': phone.text,
                  'landline': landline.text,
                  'email': email.text,
                  'tags': tags.text,
                  'notes': notes.text,
                  'co_debtor_name': coDebtorName.text,
                  'co_debtor_document': coDebtorDocument.text,
                  'co_debtor_phone': coDebtorPhone.text,
                  'reference1_name': referenceName.text,
                  'reference1_relation': referenceRelation.text,
                  'reference1_phone': referencePhone.text,
                  'is_active': existing?['is_active'] != false,
                };
                try {
                  if (existing == null) {
                    await repo.addCustomer(values);
                  } else {
                    await repo.updateCustomer(existing['id'].toString(), values);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  reload();
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      lastName.dispose();
      document.dispose();
      address.dispose();
      phone.dispose();
      landline.dispose();
      email.dispose();
      notes.dispose();
      tags.dispose();
      coDebtorName.dispose();
      coDebtorDocument.dispose();
      coDebtorPhone.dispose();
      referenceName.dispose();
      referenceRelation.dispose();
      referencePhone.dispose();
    }
  }

  Future<void> confirmDelete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Cliente'),
        content: Text(
          'Deseja excluir ${fullName(row)}? Esta ação exige confirmação.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repo.deleteCustomer(row['id'].toString());
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> toggleActive(Map<String, dynamic> row) async {
    final active = row['is_active'] != false;
    try {
      await repo.setActive(row['id'].toString(), !active);
      reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> editSignature(Map<String, dynamic> row) async {
    final current = row['signature_data']?.toString();
    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignatureDialog(initialData: current),
    );
    if (result == null) return;
    try {
      await repo.saveSignature(row['id'].toString(), result);
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura salva.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  List<xls.CellValue?> excelRow(List<Object?> values) {
    return values
        .map<xls.CellValue?>(
          (value) => xls.TextCellValue(value?.toString() ?? ''),
        )
        .toList();
  }

  List<String> get excelHeaders => const [
        'nome',
        'sobrenome',
        'cpf_cnpj',
        'endereco',
        'telefone',
        'telefone_fixo',
        'email',
        'etiquetas',
        'observacoes',
        'codevedor',
        'cpf_cnpj_codevedor',
        'telefone_codevedor',
        'referencia_nome',
        'referencia_relacao',
        'referencia_telefone',
        'status',
      ];

  Uint8List buildCustomerExcel(
    List<Map<String, dynamic>> rows, {
    required bool model,
  }) {
    final excel = xls.Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Clientes') {
      excel.rename(defaultSheet, 'Clientes');
    }
    final sheet = excel['Clientes'];
    sheet.appendRow(excelRow(excelHeaders));

    if (!model) {
      for (final row in rows) {
        sheet.appendRow(
          excelRow([
            row['name'],
            row['last_name'],
            row['document'],
            row['address'],
            row['phone'],
            row['landline'],
            row['email'],
            ((row['tags'] as List?) ?? const []).join(', '),
            row['notes'],
            row['co_debtor_name'],
            row['co_debtor_document'],
            row['co_debtor_phone'],
            row['reference1_name'],
            row['reference1_relation'],
            row['reference1_phone'],
            row['is_active'] == false ? 'Inativo' : 'Ativo',
          ]),
        );
      }
    } else {
      final instructions = excel['Instrucoes'];
      instructions.appendRow(
        excelRow([
          'Instruções de preenchimento',
          'Preencha uma linha por cliente. O campo nome é obrigatório.',
        ]),
      );
      instructions.appendRow(
        excelRow([
          'status',
          'Use Ativo ou Inativo. Se ficar vazio, o cliente será importado como Ativo.',
        ]),
      );
      instructions.appendRow(
        excelRow([
          'etiquetas',
          'Separe várias etiquetas por vírgula.',
        ]),
      );
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Não foi possível gerar o arquivo Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> shareExcel(Uint8List bytes, String fileName, String text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
      ),
    );
  }

  Future<void> exportCustomers(List<Map<String, dynamic>> rows) async {
    setState(() => busy = true);
    try {
      final bytes = buildCustomerExcel(rows, model: false);
      await shareExcel(bytes, 'clientes_roots.xlsx', 'Clientes Roots Cobrança');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> downloadModel() async {
    setState(() => busy = true);
    try {
      final bytes = buildCustomerExcel(const [], model: true);
      await shareExcel(
        bytes,
        'modelo_clientes_roots.xlsx',
        'Modelo de importação de clientes',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar modelo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String cellText(xls.Data? cell) {
    return cell?.value?.toString().trim() ?? '';
  }

  Future<void> importCustomers() async {
    const typeGroup = XTypeGroup(
      label: 'Excel',
      extensions: ['xlsx'],
      mimeTypes: [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
      uniformTypeIdentifiers: [
        'org.openxmlformats.spreadsheetml.sheet',
      ],
      webWildCards: [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );

    final selected = await openFile(
      acceptedTypeGroups: const [typeGroup],
    );
    if (selected == null) return;

    setState(() => busy = true);
    try {
      final bytes = await selected.readAsBytes();
      final excel = xls.Excel.decodeBytes(bytes);
      final table = excel.tables['Clientes'] ??
          (excel.tables.isEmpty ? null : excel.tables.values.first);
      if (table == null || table.rows.isEmpty) {
        throw StateError('Arquivo sem planilha de clientes.');
      }

      final headerRow = table.rows.first;
      final headerIndex = <String, int>{};
      for (var i = 0; i < headerRow.length; i++) {
        final key = cellText(headerRow[i]).toLowerCase();
        if (key.isNotEmpty) headerIndex[key] = i;
      }

      String value(List<xls.Data?> row, String key) {
        final index = headerIndex[key];
        if (index == null || index >= row.length) return '';
        return cellText(row[index]);
      }

      final items = <Map<String, dynamic>>[];
      for (var i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        final name = value(row, 'nome');
        if (name.isEmpty) continue;
        final status = value(row, 'status').toLowerCase();
        items.add({
          'name': name,
          'last_name': value(row, 'sobrenome'),
          'document': value(row, 'cpf_cnpj'),
          'address': value(row, 'endereco'),
          'phone': value(row, 'telefone'),
          'landline': value(row, 'telefone_fixo'),
          'email': value(row, 'email'),
          'tags': value(row, 'etiquetas'),
          'notes': value(row, 'observacoes'),
          'co_debtor_name': value(row, 'codevedor'),
          'co_debtor_document': value(row, 'cpf_cnpj_codevedor'),
          'co_debtor_phone': value(row, 'telefone_codevedor'),
          'reference1_name': value(row, 'referencia_nome'),
          'reference1_relation': value(row, 'referencia_relacao'),
          'reference1_phone': value(row, 'referencia_telefone'),
          'is_active': status != 'inativo',
        });
      }

      final imported = await repo.importCustomers(items);
      reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$imported cliente(s) importado(s).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showCustomersPerDay() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clientes por Dia'),
        content: SizedBox(
          width: 480,
          height: 420,
          child: FutureBuilder<Map<String, int>>(
            future: repo.customersPerDay(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}'));
              }
              final entries = (snapshot.data ?? const <String, int>{})
                  .entries
                  .toList();
              entries.sort((a, b) => b.key.compareTo(a.key));
              if (entries.isEmpty) {
                return const Center(child: Text('Nenhum cliente cadastrado.'));
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = entries[index];
                  final parsed = DateTime.tryParse(item.key);
                  final label = parsed == null
                      ? item.key
                      : DateFormat('dd/MM/yyyy').format(parsed);
                  return ListTile(
                    title: Text(label),
                    trailing: Text(
                      '${item.value}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String money(dynamic value) {
    final number =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(number);
  }

  Future<void> showMostPaid() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clientes que Mais Pagaram'),
        content: SizedBox(
          width: 520,
          height: 440,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: repo.customersMostPaid(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erro: ${snapshot.error}'));
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Center(child: Text('Nenhum pagamento registrado.'));
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(row['name']?.toString() ?? 'Cliente'),
                    trailing: Text(
                      money(row['total_paid']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget customerCard(Map<String, dynamic> row) {
    final active = row['is_active'] != false;
    final tags = ((row['tags'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasAddress = row['address']?.toString().trim().isNotEmpty ?? false;
    final hasSignature =
        row['signature_data']?.toString().trim().isNotEmpty ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(active ? Icons.person : Icons.person_off_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName(row),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          row['document'],
                          row['phone'],
                          row['email'],
                        ]
                            .where(
                              (e) =>
                                  e != null && e.toString().trim().isNotEmpty,
                            )
                            .join(' • '),
                      ),
                      if (hasAddress)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(row['address'].toString()),
                        ),
                    ],
                  ),
                ),
                Chip(label: Text(active ? 'Ativo' : 'Inativo')),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final tag in tags) Chip(label: Text(tag))],
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => customerForm(existing: row),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar Cliente'),
                ),
                OutlinedButton.icon(
                  onPressed: () => toggleActive(row),
                  icon: Icon(
                    active
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt_1_outlined,
                  ),
                  label: Text(active ? 'Desativar Cliente' : 'Reativar Cliente'),
                ),
                OutlinedButton.icon(
                  onPressed: () => editSignature(row),
                  icon: const Icon(Icons.draw_outlined),
                  label: Text(
                    hasSignature
                        ? 'Editar Assinatura'
                        : 'Assinatura do Cliente',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => confirmDelete(row),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir Cliente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final all = snapshot.data ?? const <Map<String, dynamic>>[];
          final rows = filtered(all);
          final freeLimit = repo.configuredFreeLimit;

          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          busy ? null : () => customerForm(existing: null),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Adicionar Cliente'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : importCustomers,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Importar Clientes via Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => exportCustomers(all),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Exportar Clientes para Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : downloadModel,
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Baixar Modelo de Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : showCustomersPerDay,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Clientes por Dia'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : showMostPaid,
                      icon: const Icon(Icons.leaderboard_outlined),
                      label: const Text('Clientes que Mais Pagaram'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (repo.isPremium)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(Icons.workspace_premium_outlined, size: 18),
                      label: Text('Clientes Ilimitados • Premium'),
                    ),
                  )
                else if (freeLimit != null && freeLimit > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text('${all.length}/$freeLimit clientes'),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Buscar Cliente',
                    hintText: 'Nome, documento, telefone ou outro critério',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Ativos'),
                      selected: filter == 'ativos',
                      onSelected: (_) => setState(() => filter = 'ativos'),
                    ),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: filter == 'todos',
                      onSelected: (_) => setState(() => filter = 'todos'),
                    ),
                    ChoiceChip(
                      label: const Text('Clientes Inativos'),
                      selected: filter == 'inativos',
                      onSelected: (_) => setState(() => filter = 'inativos'),
                    ),
                    ChoiceChip(
                      label: const Text('Clientes Reativáveis'),
                      selected: filter == 'reativaveis',
                      onSelected: (_) => setState(() => filter = 'reativaveis'),
                    ),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<String>(
                        value: order,
                        decoration: const InputDecoration(
                          labelText: 'Ordenação',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'nome',
                            child: Text('Nome'),
                          ),
                          DropdownMenuItem(
                            value: 'cadastro',
                            child: Text('Cadastro'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => order = value ?? 'nome'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Listar Clientes • ${rows.length} resultado(s)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (rows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Nenhum cliente encontrado.')),
                    ),
                  ),
                for (final row in rows) ...[
                  customerCard(row),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class SignatureDialog extends StatefulWidget {
  final String? initialData;

  const SignatureDialog({super.key, this.initialData});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final strokes = <List<Offset>>[];

  @override
  void initState() {
    super.initState();
    final raw = widget.initialData?.trim();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final stroke in decoded) {
          if (stroke is! List) continue;
          final points = <Offset>[];
          for (final point in stroke) {
            if (point is List && point.length >= 2) {
              final x = point[0];
              final y = point[1];
              if (x is num && y is num) {
                points.add(Offset(x.toDouble(), y.toDouble()));
              }
            }
          }
          if (points.isNotEmpty) strokes.add(points);
        }
      }
    } catch (_) {}
  }

  String encodeSignature() {
    return jsonEncode([
      for (final stroke in strokes)
        [
          for (final point in stroke) [point.dx, point.dy],
        ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assinatura do Cliente'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade500),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  setState(() {
                    strokes.add([details.localPosition]);
                  });
                },
                onPanUpdate: (details) {
                  if (strokes.isEmpty) return;
                  setState(() {
                    strokes.last.add(details.localPosition);
                  });
                },
                child: CustomPaint(
                  painter: SignaturePainter(strokes),
                  size: Size.infinite,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Assine no quadro acima.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(strokes.clear),
          child: const Text('Limpar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: strokes.isEmpty
              ? null
              : () => Navigator.pop(context, encodeSignature()),
          child: const Text('Salvar Assinatura'),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        final dotPaint = Paint()
          ..color = Colors.black
          ..style = PaintingStyle.fill;
        canvas.drawCircle(stroke.first, 1.2, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
