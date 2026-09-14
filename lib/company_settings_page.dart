import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'company_settings_repository.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final repo = CompanySettingsRepository();
  final picker = ImagePicker();
  final companyName = TextEditingController();
  final tradeName = TextEditingController();
  final taxId = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final lateInterest = TextEditingController();
  final lateFee = TextEditingController();

  bool loading = true;
  bool saving = false;
  String lateFeeType = 'percent';
  String? logoBase64;
  String? signatureBase64;
  final Set<String> paymentMethods = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    companyName.dispose();
    tradeName.dispose();
    taxId.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
    lateInterest.dispose();
    lateFee.dispose();
    super.dispose();
  }

  double parseNumber(String value) =>
      double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> load() async {
    try {
      final data = await repo.load();
      companyName.text = data['company_name']?.toString() ?? '';
      tradeName.text = data['trade_name']?.toString() ?? '';
      taxId.text = data['tax_id']?.toString() ?? '';
      address.text = data['address']?.toString() ?? '';
      phone.text = data['phone']?.toString() ?? '';
      email.text = data['email']?.toString() ?? '';
      lateInterest.text = ((data['late_interest_rate'] as num?)?.toDouble() ?? 0)
          .toString()
          .replaceAll('.', ',');
      lateFee.text = ((data['late_fee_base'] as num?)?.toDouble() ?? 0)
          .toString()
          .replaceAll('.', ',');
      lateFeeType = data['late_fee_type']?.toString() == 'fixed' ? 'fixed' : 'percent';
      logoBase64 = data['logo_base64']?.toString();
      signatureBase64 = data['signature_base64']?.toString();
      paymentMethods
        ..clear()
        ..addAll(List<String>.from(data['payment_methods'] ?? CompanySettingsRepository.paymentOptions));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> pickImage() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Uint8List? decodeImage(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final interest = parseNumber(lateInterest.text);
    final fee = parseNumber(lateFee.text);
    if (interest <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A taxa padrão de juros de mora deve ser maior que 0.')),
      );
      return;
    }
    if (paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habilite ao menos uma forma de pagamento.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await repo.save(
        companyName: companyName.text,
        tradeName: tradeName.text,
        taxId: taxId.text,
        address: address.text,
        phone: phone.text,
        email: email.text,
        logoBase64: logoBase64,
        signatureBase64: signatureBase64,
        lateInterestRate: interest,
        lateFeeBase: fee,
        lateFeeType: lateFeeType,
        paymentMethods: CompanySettingsRepository.paymentOptions
            .where(paymentMethods.contains)
            .toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar configurações: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void tutorial() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutorial de Configuração da Empresa'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Preencha os dados básicos da empresa: nome, nome fantasia, CNPJ, endereço, telefone e e-mail.\n\n'
            '2. Envie o logotipo que será usado em recibos e documentos.\n\n'
            '3. Envie a assinatura digital do representante para os documentos oficiais.\n\n'
            '4. Defina a taxa padrão de juros de mora.\n\n'
            '5. Configure a multa por atraso como percentual ou valor fixo.\n\n'
            '6. Marque as formas de pagamento aceitas pela empresa.\n\n'
            '7. Toque em Salvar configurações para gravar as alterações.',
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final logoBytes = decodeImage(logoBase64);
    final signatureBytes = decodeImage(signatureBase64);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => loading = true);
        await load();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Configurações da Empresa', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              IconButton(tooltip: 'Tutorial', onPressed: tutorial, icon: const Icon(Icons.help_outline)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  sectionTitle('Dados Básicos da Empresa'),
                  TextField(controller: companyName, decoration: const InputDecoration(labelText: 'Nome / Razão Social', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: tradeName, decoration: const InputDecoration(labelText: 'Nome fantasia', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: taxId, decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: address, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Endereço completo', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionTitle('Logotipo da Empresa'),
                  if (logoBytes != null)
                    SizedBox(height: 120, child: Image.memory(logoBytes, fit: BoxFit.contain)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await pickImage();
                      if (value != null && mounted) setState(() => logoBase64 = value);
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(logoBytes == null ? 'Enviar logotipo' : 'Trocar logotipo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionTitle('Assinatura da Empresa'),
                  if (signatureBytes != null)
                    SizedBox(height: 120, child: Image.memory(signatureBytes, fit: BoxFit.contain)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await pickImage();
                      if (value != null && mounted) setState(() => signatureBase64 = value);
                    },
                    icon: const Icon(Icons.draw_outlined),
                    label: Text(signatureBytes == null ? 'Enviar assinatura digital' : 'Trocar assinatura digital'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  sectionTitle('Configurar Taxa de Juros de Mora'),
                  TextField(
                    controller: lateInterest,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Taxa padrão de juros de mora (%)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  sectionTitle('Configurar Multa por Atraso'),
                  DropdownButtonFormField<String>(
                    initialValue: lateFeeType,
                    decoration: const InputDecoration(labelText: 'Tipo da multa', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'percent', child: Text('Percentual (%)')),
                      DropdownMenuItem(value: 'fixed', child: Text('Valor fixo (R\$)')),
                    ],
                    onChanged: (value) => setState(() => lateFeeType = value ?? 'percent'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lateFee,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: lateFeeType == 'percent' ? 'Percentual da multa (%)' : 'Valor fixo da multa (R\$)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle('Configurar Formas de Pagamento'),
                  ...CompanySettingsRepository.paymentOptions.map(
                    (method) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(method),
                      value: paymentMethods.contains(method),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          paymentMethods.add(method);
                        } else {
                          paymentMethods.remove(method);
                        }
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'Salvando...' : 'Salvar configurações'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
