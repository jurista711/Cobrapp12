import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'documents_repository.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final repo = DocumentsRepository();
  bool loading = true;
  List<Map<String, dynamic>> rows = [];

  static const Map<String, String> examples = {
    'contrato':
        'CONTRATO DE MÚTUO\n\n'
        'Mutuário: {{cliente_nome}}, documento {{cliente_documento}}, endereço {{cliente_endereco}}.\n'
        'Capital: R\$ {{capital}}. Total: R\$ {{total}}. Juros: {{juros}}% ao mês. Parcelas: {{parcelas}}.\n\n'
        'Condições e cláusulas acordadas entre as partes.',
    'recibo':
        'RECIBO DE PAGAMENTO\n\n'
        'Recebi de {{cliente_nome}}, documento {{cliente_documento}}, o pagamento referente ao empréstimo selecionado.\n'
        'Valor/total do contrato: R\$ {{total}}.\n'
        'Data: {{data}}.',
    'compromisso':
        'COMPROMISSO DE PAGAMENTO\n\n'
        'Eu, {{cliente_nome}}, documento {{cliente_documento}}, assumo o compromisso de pagamento relativo ao empréstimo de R\$ {{capital}}, nas condições acordadas.',
    'personalizado': '',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await repo.templates();
    if (!mounted) return;
    setState(() {
      rows = data;
      loading = false;
    });
  }

  Future<void> edit([Map<String, dynamic>? template]) async {
    final title = TextEditingController(
      text: template?['title']?.toString() ?? '',
    );
    final body = TextEditingController(
      text: template?['body']?.toString() ?? '',
    );
    var type = template?['document_type']?.toString() ?? 'personalizado';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            template == null
                ? 'Criar Modelo de Documento'
                : 'Editar Modelo de Documento',
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'contrato',
                        child: Text('Contrato de Mútuo'),
                      ),
                      DropdownMenuItem(
                        value: 'recibo',
                        child: Text('Recibo de Pagamento'),
                      ),
                      DropdownMenuItem(
                        value: 'compromisso',
                        child: Text('Compromisso de Pagamento'),
                      ),
                      DropdownMenuItem(
                        value: 'personalizado',
                        child: Text('Personalizado'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => type = value);
                      if (body.text.isEmpty) {
                        body.text = examples[value] ?? '';
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Tipo'),
                  ),
                  TextField(
                    controller: body,
                    minLines: 12,
                    maxLines: 20,
                    decoration: const InputDecoration(
                      labelText: 'Texto do modelo',
                      hintText:
                          'Use {{cliente_nome}}, {{cliente_documento}}, {{cliente_endereco}}, {{capital}}, {{total}}, {{juros}}, {{parcelas}}, {{data}}',
                    ),
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
                if (title.text.trim().isEmpty) return;
                await repo.saveTemplate(
                  id: template?['id']?.toString(),
                  title: title.text.trim(),
                  type: type,
                  body: body.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                await load();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> generate(Map<String, dynamic> template) async {
    final customers = await repo.customers();
    if (!mounted) return;

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um cliente antes de gerar o documento.'),
        ),
      );
      return;
    }

    Map<String, dynamic>? customer;
    Map<String, dynamic>? loan;
    List<Map<String, dynamic>> loans = [];
    final editor = TextEditingController(
      text: template['body']?.toString() ?? '',
    );
    var clientSignature = '';
    var responsibleSignature = '';
    var witnessSignature = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Gerar — ${template['title']}'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    items: customers
                        .map(
                          (item) => DropdownMenuItem<Map<String, dynamic>>(
                            value: item,
                            child: Text(
                              item['name']?.toString() ?? 'Cliente',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      customer = value;
                      loan = null;
                      final loadedLoans = value == null
                          ? <Map<String, dynamic>>[]
                          : await repo.loans(value['id'].toString());
                      if (!dialogContext.mounted) return;
                      setDialogState(() => loans = loadedLoans);
                    },
                    decoration: const InputDecoration(labelText: 'Cliente'),
                  ),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: loan,
                    items: loans
                        .map(
                          (item) => DropdownMenuItem<Map<String, dynamic>>(
                            value: item,
                            child: Text(
                              'Empréstimo R\$ ${item['principal']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => loan = value),
                    decoration:
                        const InputDecoration(labelText: 'Empréstimo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: editor,
                    minLines: 12,
                    maxLines: 18,
                    decoration: const InputDecoration(
                      labelText: 'Texto livre antes de gerar',
                    ),
                  ),
                  TextField(
                    onChanged: (value) => clientSignature = value,
                    decoration: const InputDecoration(
                      labelText: 'Assinatura do cliente',
                    ),
                  ),
                  TextField(
                    onChanged: (value) => responsibleSignature = value,
                    decoration: const InputDecoration(
                      labelText: 'Assinatura do responsável',
                    ),
                  ),
                  TextField(
                    onChanged: (value) => witnessSignature = value,
                    decoration: const InputDecoration(
                      labelText: 'Assinatura da testemunha (se aplicável)',
                    ),
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
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Gerar'),
              onPressed: customer == null
                  ? null
                  : () async {
                      var output = editor.text;
                      final replacements = <String, String>{
                        '{{cliente_nome}}': customer?['name']?.toString() ?? '',
                        '{{cliente_documento}}':
                            customer?['document']?.toString() ?? '',
                        '{{cliente_endereco}}':
                            customer?['address']?.toString() ?? '',
                        '{{capital}}': loan?['principal']?.toString() ?? '',
                        '{{total}}': loan?['total_amount']?.toString() ?? '',
                        '{{juros}}': loan?['interest_rate']?.toString() ?? '',
                        '{{parcelas}}':
                            loan?['installments']?.toString() ?? '',
                        '{{data}}': DateTime.now()
                            .toIso8601String()
                            .substring(0, 10),
                      };
                      for (final entry in replacements.entries) {
                        output = output.replaceAll(entry.key, entry.value);
                      }

                      await repo.saveGenerated(
                        templateId: template['id']?.toString(),
                        customerId: customer?['id']?.toString(),
                        loanId: loan?['id']?.toString(),
                        title: template['title']?.toString() ?? 'Documento',
                        body: output,
                        clientSignature: clientSignature,
                        responsibleSignature: responsibleSignature,
                        witnessSignature: witnessSignature,
                      );

                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.MultiPage(
                          pageFormat: PdfPageFormat.a4,
                          build: (_) => [
                            pw.Text(
                              template['title']?.toString() ?? 'Documento',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 18),
                            pw.Text(output),
                            pw.SizedBox(height: 36),
                            pw.Text(
                              'Assinatura do cliente: $clientSignature',
                            ),
                            pw.Text(
                              'Responsável: $responsibleSignature',
                            ),
                            if (witnessSignature.isNotEmpty)
                              pw.Text('Testemunha: $witnessSignature'),
                          ],
                        ),
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      await Printing.layoutPdf(
                        onLayout: (_) => pdf.save(),
                        name:
                            '${template['title']?.toString() ?? 'documento'}.pdf',
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> help() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tutorial de Criação de Documentos'),
        content: const Text(
          'Crie um modelo novo ou clone um existente. Edite o texto e use os campos automáticos indicados. Ao usar um modelo, selecione cliente e empréstimo, revise o texto, informe as assinaturas quando aplicável e toque em Gerar para criar o documento pronto para impressão ou salvamento.',
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

  Future<void> deleteTemplate(Map<String, dynamic> template) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir modelo'),
            content: Text(
              'Deseja excluir o modelo "${template['title']?.toString() ?? 'Modelo'}"?',
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
        ) ??
        false;
    if (!confirmed) return;
    await repo.deleteTemplate(template['id'].toString());
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Modelos de Documentos',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Ajuda',
                  onPressed: help,
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            ),
            const Text(
              'Crie, edite, clone, compartilhe e gere documentos com dados de clientes e empréstimos.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Criar Modelo de Documento'),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum modelo personalizado. Crie um modelo para começar.',
                  ),
                ),
              ),
            for (final template in rows)
              Card(
                child: ListTile(
                  title: Text(
                    template['title']?.toString() ?? 'Modelo',
                  ),
                  subtitle: Text(
                    template['document_type']?.toString() ?? 'personalizado',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      switch (action) {
                        case 'usar':
                          await generate(template);
                        case 'editar':
                          await edit(template);
                        case 'clonar':
                          await repo.cloneTemplate(template);
                          await load();
                        case 'compartilhar':
                          await generate(template);
                        case 'excluir':
                          await deleteTemplate(template);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'usar',
                        child: Text('Usar modelo'),
                      ),
                      PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar modelo'),
                      ),
                      PopupMenuItem(
                        value: 'clonar',
                        child: Text('Clonar modelo'),
                      ),
                      PopupMenuItem(
                        value: 'compartilhar',
                        child: Text('Compartilhar modelo'),
                      ),
                      PopupMenuItem(
                        value: 'excluir',
                        child: Text('Excluir modelo'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
