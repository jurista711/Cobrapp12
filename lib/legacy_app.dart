import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/supabase_config.dart';
import 'data/auth_repository.dart';
import 'data/cobrapp_repository.dart';
import 'calculator_page.dart';
import 'portfolio_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await initSupabase();
  runApp(const CobrApp());
}

String money(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(number);
}

String dateText(dynamic value) {
  if (value == null) return '-';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return value.toString();
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

Map<String, dynamic>? relationMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

double saldoFor(Map<String, dynamic> row) {
  final amount = (row['amount'] as num?)?.toDouble() ?? 0;
  final paid = (row['paid_amount'] as num?)?.toDouble() ?? 0;
  return (amount - paid).clamp(0, double.infinity).toDouble();
}

String collectionMessage(String name, String dueDate, double balance) {
  return 'Olá, $name. Passando para lembrar da parcela com vencimento em '
      '$dueDate. Valor em aberto: ${money(balance)}. Por favor, regularize o pagamento. Obrigado.';
}

String normalizeBrazilPhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (!digits.startsWith('55') && digits.length >= 10) digits = '55$digits';
  return digits;
}

Future<void> openWhatsApp(
  BuildContext context,
  String? phone, {
  String? message,
}) async {
  if (phone == null || phone.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente sem telefone cadastrado.')),
    );
    return;
  }
  final number = normalizeBrazilPhone(phone);
  final uri = Uri.parse(
    'https://wa.me/$number?text=${Uri.encodeComponent(message ?? 'Olá!')}',
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

Future<void> openPhone(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cliente sem telefone cadastrado.')),
    );
    return;
  }
  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\D'), '')}');
  if (!await launchUrl(uri)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
      );
    }
  }
}

class CobrApp extends StatelessWidget {
  const CobrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Roots Cobrança',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0A0618),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          secondary: Color(0xFFEC4899),
          onSecondary: Colors.white,
          tertiary: Color(0xFFEF4444),
          onTertiary: Colors.white,
          surface: Color(0xFF120A2B),
          onSurface: Color(0xFFF8F5FF),
          error: Color(0xFFFF5252),
          onError: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF17102F),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthRepository().authState,
      builder: (context, snapshot) {
        return Supabase.instance.client.auth.currentSession == null
            ? const LoginPage()
            : const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Informe e-mail e senha.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthRepository().signIn(email.text.trim(), password.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível fazer login.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 76),
                  const SizedBox(height: 12),
                  const Text(
                    'Roots Cobrança',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Gestão de empréstimos e cobranças'),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => loading ? null : login(),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : login,
                      child: Text(loading ? 'Entrando...' : 'Entrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab = 0;
  Widget page() {
    switch (tab) {
      case 1: return const CustomersPage();
      case 2: return const LoansPage();
      case 3: return const CollectionPage();
      case 4: return const CashPage();
      case 5: return const PaymentsPage();
      case 6: return const ReceiptsPage();
      case 7: return const RoutesPage();
      case 8: return const ReportsPage();
      case 9: return const PortfolioPage();
      case 10: return const CalculatorPage();
      case 11: return const SettingsPage();
      default: return const DashboardPage();
    }
  }
  void select(int index) { Navigator.of(context).pop(); setState(() => tab = index); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: tab,
        onDestinationSelected: select,
        header: Padding(padding: const EdgeInsets.fromLTRB(24,28,24,18), child: Row(children: [
          Container(width:48,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(16),gradient:const LinearGradient(colors:[Color(0xFF7C3AED),Color(0xFFA855F7)])),child:const Icon(Icons.account_balance_wallet_rounded,color:Colors.white)),
          const SizedBox(width:14), const Expanded(child: Text('Roots Cobrança',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900))),
        ])),
        children: const [
          NavigationDrawerDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:Text('Início')),
          NavigationDrawerDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:Text('Clientes')),
          NavigationDrawerDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet),label:Text('Empréstimos')),
          NavigationDrawerDestination(icon:Icon(Icons.event_available_outlined),selectedIcon:Icon(Icons.event_available),label:Text('Cobranças')),
          NavigationDrawerDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:Text('Caixa')),
          Divider(indent:16,endIndent:16),
          NavigationDrawerDestination(icon:Icon(Icons.payments_outlined),selectedIcon:Icon(Icons.payments),label:Text('Pagamentos')),
          NavigationDrawerDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:Text('Recibos')),
          NavigationDrawerDestination(icon:Icon(Icons.route_outlined),selectedIcon:Icon(Icons.route),label:Text('Rotas')),
          NavigationDrawerDestination(icon:Icon(Icons.analytics_outlined),selectedIcon:Icon(Icons.analytics),label:Text('Relatórios')),
          NavigationDrawerDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:Text('Gestão da Carteira')),
          NavigationDrawerDestination(icon:Icon(Icons.calculate_outlined),selectedIcon:Icon(Icons.calculate),label:Text('Calculadora')),
          NavigationDrawerDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:Text('Configurações')),
        ],
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFBE185D), Color(0xFFEF233C)],
            ),
          ),
        ),
        title: Row(children:[
          Container(width:38,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),gradient:const LinearGradient(colors:[Color(0xFFA855F7),Color(0xFFEC4899)])),child:const Icon(Icons.account_balance_wallet_rounded,color:Colors.white,size:22)),
          const SizedBox(width:11),
          const Text('Roots Cobrança',style:TextStyle(fontWeight:FontWeight.w900,fontSize:21)),
        ]),
        actions:[IconButton(tooltip:'Sair',onPressed:()=>CobrAppRepository().db.auth.signOut(),icon:const Icon(Icons.logout_rounded))],
      ),
      body:SafeArea(child:page()),
      bottomNavigationBar:NavigationBar(
        selectedIndex:tab>4?0:tab,
        onDestinationSelected:(index)=>setState(()=>tab=index),
        backgroundColor:const Color(0xFF120A2B),
        elevation:12,
        indicatorColor:const Color(0xFF9D174D),
        labelTextStyle:const WidgetStatePropertyAll(TextStyle(fontWeight:FontWeight.w700)),
        destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Início'),
        NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Clientes'),
        NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet),label:'Empréstimos'),
        NavigationDestination(icon:Icon(Icons.event_available_outlined),selectedIcon:Icon(Icons.event_available),label:'Cobranças'),
        NavigationDestination(icon:Icon(Icons.account_balance_outlined),selectedIcon:Icon(Icons.account_balance),label:'Caixa'),
      ]),
    );
  }
}
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const StatCard({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(clipBehavior: Clip.antiAlias, color: const Color(0xFF17102F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFF3B1F6B))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: const Color(0xFF5B21B6), child: Icon(icon, size: 20, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: CobrAppRepository().totals(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        final x = snapshot.data ?? <String, dynamic>{};
        return Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors: [Color(0xFF160A31), Color(0xFF0A0618)])),
          child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text('Resumo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 7),
                  Container(width:125,height:5,decoration:BoxDecoration(borderRadius:BorderRadius.circular(99),gradient:const LinearGradient(colors:[Color(0xFFEC4899),Color(0xFF8B5CF6)]))),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: StatCard(label: 'Clientes', value: '${x['customers'] ?? 0}', icon: Icons.people)),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(label: 'Ativos', value: '${x['activeLoans'] ?? 0}', icon: Icons.account_balance_wallet)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: StatCard(label: 'Emprestado', value: money(x['loans']), icon: Icons.trending_up)),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(label: 'Recebido', value: money(x['payments']), icon: Icons.payments)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: StatCard(label: 'Em aberto', value: money(x['pending']), icon: Icons.pending_actions)),
                    const SizedBox(width: 10),
                    Expanded(child: StatCard(label: 'Em atraso', value: money(x['overdue']), icon: Icons.warning_amber_rounded)),
                  ]),
                  const SizedBox(height: 22),
                  Card(clipBehavior: Clip.antiAlias, color: const Color(0xFF21113F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF7C3AED))),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children:[Icon(Icons.cloud_done_rounded,color:Color(0xFF22C55E)),SizedBox(width:10),Text('Migração Supabase', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))]),
                          const SizedBox(height: 8),
                          Text('Autenticação, banco de dados e armazenamento estão preparados para substituir o Firebase.', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
        );
      },
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final repo = CobrAppRepository();
  late Future<Map<String, dynamic>> future;
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() {
    future = repo.portfolioReport(from: from, to: to);
  }

  void reload() => setState(load);

  String fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  Future<void> pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: from != null && to != null ? DateTimeRange(start: from!, end: to!) : null,
    );
    if (range != null) {
      from = range.start;
      to = range.end;
      reload();
    }
  }

  Future<void> exportPdf() async {
    final data = await future;
    final customers = List<Map<String, dynamic>>.from(data['customers'] ?? const []);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('Roots Cobrança - Relatório da carteira')),
          pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
          if (from != null && to != null) pw.Text('Período: ${fmtDate(from!)} a ${fmtDate(to!)}'),
          pw.SizedBox(height: 12),
          pw.Text('Emprestado: ${money(data['loaned'])}'),
          pw.Text('Recebido: ${money(data['received'])}'),
          pw.Text('Em aberto: ${money(data['pending'])}'),
          pw.Text('Em atraso: ${money(data['overdue'])}'),
          pw.Text('Saldo do período: ${money(data['balance'])}'),
          pw.SizedBox(height: 16),
          pw.Text('Carteira por cliente'),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ['Cliente', 'Empréstimos', 'Emprestado', 'Recebido', 'Em aberto'],
            data: customers.map((row) => [
              row['name'] ?? '',
              row['loans'] ?? 0,
              money(row['principal']),
              money(row['received']),
              money(row['pending']),
            ]).toList(),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await document.save(), filename: 'roots_cobranca_relatorio.pdf');
  }

  Future<void> exportCsv() async {
    final data = await future;
    final customers = List<Map<String, dynamic>>.from(data['customers'] ?? const []);
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    final rows = <String>['Cliente,Emprestimos,Emprestado,Recebido,Em aberto'];
    for (final row in customers) {
      rows.add([
        quote(row['name']?.toString() ?? ''),
        '${row['loans'] ?? 0}',
        '${row['principal'] ?? 0}',
        '${row['received'] ?? 0}',
        '${row['pending'] ?? 0}',
      ].join(','));
    }
    final bytes = utf8.encode('\uFEFF${rows.join('\r\n')}');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cobrapp_carteira.csv');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Carteira Roots Cobrança'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios e carteira'),
        actions: [
          IconButton(tooltip: 'PDF', onPressed: exportPdf, icon: const Icon(Icons.picture_as_pdf_outlined)),
          IconButton(tooltip: 'CSV', onPressed: exportCsv, icon: const Icon(Icons.table_view_outlined)),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final data = snapshot.data ?? <String, dynamic>{};
          final customers = List<Map<String, dynamic>>.from(data['customers'] ?? const []);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              OutlinedButton.icon(
                onPressed: pickRange,
                icon: const Icon(Icons.date_range),
                label: Text(from == null || to == null ? 'Filtrar por período' : '${fmtDate(from!)} a ${fmtDate(to!)}'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: StatCard(label: 'Emprestado', value: money(data['loaned']), icon: Icons.trending_up)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(label: 'Recebido', value: money(data['received']), icon: Icons.payments)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: StatCard(label: 'Em aberto', value: money(data['pending']), icon: Icons.pending_actions)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(label: 'Em atraso', value: money(data['overdue']), icon: Icons.warning_amber_rounded)),
              ]),
              const SizedBox(height: 8),
              Card(child: ListTile(leading: const Icon(Icons.account_balance), title: const Text('Saldo do período'), trailing: Text(money(data['balance']), style: const TextStyle(fontWeight: FontWeight.w800)))),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhum cliente encontrado.')))),
              for (final row in customers)
                Card(
                  child: ListTile(
                    title: Text(row['name']?.toString() ?? 'Cliente'),
                    subtitle: Text('${row['loans'] ?? 0} empréstimo(s) • Emprestado ${money(row['principal'])} • Em aberto ${money(row['pending'])}'),
                    trailing: Text(money(row['received'])),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.customers();
  }

  void refresh() => setState(() => future = repo.customers());

  Future<void> form({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phone = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final document = TextEditingController(text: existing?['document']?.toString() ?? '');
    final address = TextEditingController(text: existing?['address']?.toString() ?? '');
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Novo cliente' : 'Editar cliente'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone')),
              TextField(controller: document, decoration: const InputDecoration(labelText: 'CPF/CNPJ')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Endereço')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                try {
                  if (existing == null) {
                    await repo.addCustomer(name: name.text.trim(), phone: phone.text.trim(), document: document.text.trim(), address: address.text.trim(), notes: notes.text.trim());
                  } else {
                    await repo.updateCustomer(id: existing['id'].toString(), name: name.text.trim(), phone: phone.text.trim(), document: document.text.trim(), address: address.text.trim(), notes: notes.text.trim());
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  refresh();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      phone.dispose();
      document.dispose();
      address.dispose();
      notes.dispose();
    }
  }

  Future<void> remove(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text('Excluir ${row['name'] ?? 'este cliente'}? Os empréstimos relacionados também serão afetados conforme as regras do banco.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteCustomer(row['id'].toString());
      refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(onPressed: form, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Center(child: Text('Nenhum cliente cadastrado.'));
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final row = rows[index];
                final phone = row['phone']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(row['name']?.toString() ?? ''),
                    subtitle: Text([row['phone'], row['document'], row['address']].where((v) => v != null && v.toString().isNotEmpty).join(' • ')),
                    onTap: () => form(existing: row),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (phone.isNotEmpty)
                          IconButton(tooltip: 'WhatsApp', icon: const Icon(Icons.chat_outlined), onPressed: () => openWhatsApp(context, phone, message: 'Olá, ${row['name']}.')),
                        if (phone.isNotEmpty)
                          IconButton(tooltip: 'Ligar', icon: const Icon(Icons.phone_outlined), onPressed: () => openPhone(context, phone)),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') form(existing: row);
                            if (value == 'delete') remove(row);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.loans();
  }

  void refresh() => setState(() => future = repo.loans());

  Future<void> add() async {
    final customers = await repo.customers();
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre um cliente primeiro.')));
      return;
    }
    String customerId = customers.first['id'].toString();
    final principal = TextEditingController();
    final interest = TextEditingController(text: '20');
    final installments = TextEditingController(text: '4');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('Novo empréstimo'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: customerId,
                  items: [for (final customer in customers) DropdownMenuItem(value: customer['id'].toString(), child: Text(customer['name']?.toString() ?? 'Cliente'))],
                  onChanged: (value) => setDialog(() => customerId = value ?? customerId),
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                TextField(controller: principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor emprestado')),
                TextField(controller: interest, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Juros (%)')),
                TextField(controller: installments, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade de parcelas')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  final p = double.tryParse(principal.text.replaceAll(',', '.'));
                  final i = double.tryParse(interest.text.replaceAll(',', '.')) ?? 0;
                  final n = int.tryParse(installments.text) ?? 0;
                  if (p == null || p <= 0 || n <= 0) return;
                  try {
                    final result = await repo.addLoan(customerId: customerId, principal: p, installments: n, interest: i);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    refresh();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Empréstimo criado. Total: ${money(result['total_amount'] ?? result['total'])}')));
                  } catch (e) {
                    if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                },
                child: const Text('Criar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      principal.dispose();
      interest.dispose();
      installments.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empréstimos')),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Center(child: Text('Nenhum empréstimo cadastrado.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final row = rows[index];
              final customer = relationMap(row['cobrapp_customers']);
              final installments = List<Map<String, dynamic>>.from((row['cobrapp_installments'] as List?) ?? const []);
              final total = (row['total_amount'] as num?)?.toDouble() ?? (row['principal'] as num?)?.toDouble() ?? 0;
              return Card(
                child: ExpansionTile(
                  title: Text(customer?['name']?.toString() ?? 'Cliente'),
                  subtitle: Text('${money(total)} • ${installments.length} parcelas • ${row['interest_rate'] ?? 0}% juros'),
                  trailing: Text(row['status']?.toString() ?? ''),
                  children: [
                    for (final installment in installments)
                      ListTile(
                        dense: true,
                        title: Text('Parcela ${installment['number']} — ${money(installment['amount'])}'),
                        subtitle: Text('Vencimento ${dateText(installment['due_date'])} • Pago ${money(installment['paid_amount'])}'),
                        trailing: Text(installment['status']?.toString() ?? ''),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.payments();
  }

  void refresh() => setState(() => future = repo.payments());

  Future<void> add() async {
    final rows = await repo.installments();
    if (!mounted) return;
    final pending = rows.where((row) => row['status'] != 'paid' && saldoFor(row) > 0).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não há parcelas pendentes.')));
      return;
    }
    String installmentId = pending.first['id'].toString();
    String mode = 'total';
    final amount = TextEditingController();
    final method = TextEditingController(text: 'Dinheiro');
    final notes = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('Registrar pagamento'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: installmentId,
                  items: [
                    for (final row in pending)
                      DropdownMenuItem(value: row['id'].toString(), child: Text('${relationMap(row['cobrapp_customers'])?['name'] ?? 'Cliente'} • Parcela ${row['number']} • ${money(saldoFor(row))}')),
                  ],
                  onChanged: (value) => setDialog(() => installmentId = value ?? installmentId),
                  decoration: const InputDecoration(labelText: 'Parcela'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  items: const [
                    DropdownMenuItem(value: 'total', child: Text('Pagamento total/parcial')),
                    DropdownMenuItem(value: 'interest', child: Text('Somente juros')),
                    DropdownMenuItem(value: 'late_interest', child: Text('Juros de atraso')),
                  ],
                  onChanged: (value) => setDialog(() => mode = value ?? mode),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
                TextField(controller: method, decoration: const InputDecoration(labelText: 'Forma de pagamento')),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observação')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(amount.text.replaceAll(',', '.'));
                  if (value == null || value <= 0) return;
                  try {
                    final result = await repo.addPayment(installmentId: installmentId, amount: value, method: method.text.trim(), notes: notes.text.trim(), type: mode);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    refresh();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['message'] ?? 'Pagamento registrado.'} Saldo: ${money(result['remaining'])}')));
                  } catch (e) {
                    if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                },
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amount.dispose();
      method.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos')),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Center(child: Text('Nenhum pagamento registrado.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final row = rows[index];
              final type = row['type']?.toString() ?? 'total';
              final customer = relationMap(row['cobrapp_customers']);
              final installment = relationMap(row['cobrapp_installments']);
              final icon = type == 'interest' ? Icons.percent : type == 'late_interest' ? Icons.warning_amber_rounded : Icons.payments;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(icon)),
                  title: Text(customer?['name']?.toString() ?? 'Cliente'),
                  subtitle: Text('${type == 'interest' ? 'Somente juros' : type == 'late_interest' ? 'Juros de atraso' : 'Pagamento'} • Parcela ${installment?['number'] ?? '-'} • ${dateText(row['paid_at'])} • ${row['method'] ?? ''}'),
                  trailing: Text(money(row['amount'])),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({super.key});

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.receipts();
  }

  void refresh() => setState(() => future = repo.receipts());

  Future<void> shareReceipt(Map<String, dynamic> receipt) async {
    final text = [
      'Roots Cobrança — Recibo',
      'Recibo: ${receipt['receipt_number'] ?? receipt['id'] ?? '-'}',
      'Cliente: ${relationMap(receipt['cobrapp_customers'])?['name'] ?? receipt['customer_name'] ?? '-'}',
      'Valor: ${money(receipt['amount'])}',
      'Data: ${dateText(receipt['issued_at'])}',
    ].join('\n');
    final document = pw.Document();
    document.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text(text))));
    await Printing.sharePdf(bytes: await document.save(), filename: 'recibo_${receipt['receipt_number'] ?? 'cobrapp'}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recibos')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Center(child: Text('Nenhum recibo emitido.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final row = rows[index];
              final customer = relationMap(row['cobrapp_customers']);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('Recibo #${row['receipt_number'] ?? '-'}'),
                  subtitle: Text('${customer?['name'] ?? row['customer_name'] ?? 'Cliente'} • ${dateText(row['issued_at'])}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(money(row['amount'])),
                    IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => shareReceipt(row)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class CashPage extends StatefulWidget {
  const CashPage({super.key});

  @override
  State<CashPage> createState() => _CashPageState();
}

class _CashPageState extends State<CashPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.expenses();
  }

  void refresh() => setState(() => future = repo.expenses());

  Future<void> add() async {
    final amount = TextEditingController();
    final description = TextEditingController();
    final category = TextEditingController(text: 'Geral');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nova saída'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Categoria')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(amount.text.replaceAll(',', '.'));
                if (value == null || value <= 0 || description.text.trim().isEmpty) return;
                try {
                  await repo.addExpense(amount: value, description: description.text.trim(), category: category.text.trim().isEmpty ? 'Geral' : category.text.trim());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  refresh();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      amount.dispose();
      description.dispose();
      category.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Caixa')),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.remove)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Controle de saídas'), subtitle: Text('Registre despesas e acompanhe o caixa junto aos pagamentos recebidos.'))),
              if (rows.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Nenhuma saída registrada.'))),
              for (final row in rows)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.arrow_downward)),
                    title: Text(money(row['amount'])),
                    subtitle: Text('${row['description'] ?? ''} • ${row['category'] ?? 'Geral'} • ${dateText(row['spent_at'])}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await repo.deleteExpense(row['id'].toString());
                        refresh();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.installments();
  }

  void refresh() => setState(() => future = repo.installments());

  Future<void> cobrar(Map<String, dynamic> row) async {
    final balance = saldoFor(row);
    if (balance <= 0) return;
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final method = TextEditingController(text: 'Dinheiro');
    final notes = TextEditingController();
    String type = 'total';
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: Text('Cobrar parcela ${row['number']}'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Cliente: ${relationMap(row['cobrapp_customers'])?['name'] ?? 'Cliente'}'),
                Text('Saldo: ${money(balance)}'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'total', child: Text('Pagamento')),
                    DropdownMenuItem(value: 'interest', child: Text('Somente juros')),
                    DropdownMenuItem(value: 'late_interest', child: Text('Juros de atraso')),
                  ],
                  onChanged: (value) => setDialog(() => type = value ?? type),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Valor')),
                TextField(controller: method, decoration: const InputDecoration(labelText: 'Forma de pagamento')),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observação')),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  final value = double.tryParse(amount.text.replaceAll(',', '.'));
                  if (value == null || value <= 0) return;
                  try {
                    final result = await repo.addPayment(installmentId: row['id'].toString(), amount: value, method: method.text.trim(), notes: notes.text.trim(), type: type);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    refresh();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Cobrança registrada.')));
                  } catch (e) {
                    if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                  }
                },
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amount.dispose();
      method.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cobranças')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final all = snapshot.data ?? const <Map<String, dynamic>>[];
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final rows = all.where((row) => row['status']?.toString() != 'paid' && saldoFor(row) > 0).toList();
          final overdue = rows.where((row) => (row['due_date']?.toString() ?? '').compareTo(today) < 0).toList();
          final dueToday = rows.where((row) => row['due_date']?.toString() == today).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(child: ListTile(leading: const Icon(Icons.warning_amber_rounded), title: Text('${overdue.length} em atraso'), subtitle: const Text('Parcelas vencidas e ainda não quitadas'))),
              Card(child: ListTile(leading: const Icon(Icons.today), title: Text('${dueToday.length} vencem hoje'), subtitle: const Text('Priorize estas cobranças'))),
              const SizedBox(height: 8),
              if (rows.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhuma cobrança pendente.'))),
              for (final row in rows)
                Card(
                  child: ListTile(
                    title: Text(relationMap(row['cobrapp_customers'])?['name']?.toString() ?? 'Cliente'),
                    subtitle: Text('Parcela ${row['number']} • Vencimento ${dateText(row['due_date'])} • Saldo ${money(saldoFor(row))}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'WhatsApp',
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () {
                          final customer = relationMap(row['cobrapp_customers']);
                          openWhatsApp(context, customer?['phone']?.toString(), message: collectionMessage(customer?['name']?.toString() ?? 'Cliente', dateText(row['due_date']), saldoFor(row)));
                        },
                      ),
                      FilledButton(onPressed: () => cobrar(row), child: const Text('Cobrar')),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final repo = CobrAppRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repo.routes();
  }

  void refresh() => setState(() => future = repo.routes());

  Future<void> routeForm({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final description = TextEditingController(text: existing?['description']?.toString() ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(existing == null ? 'Nova rota' : 'Editar rota'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome da rota')),
            TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                try {
                  if (existing == null) {
                    await repo.addRoute(name: name.text.trim(), description: description.text.trim());
                  } else {
                    await repo.updateRoute(id: existing['id'].toString(), name: name.text.trim(), description: description.text.trim());
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  refresh();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> assign(Map<String, dynamic> route) async {
    final customers = await repo.customers();
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre um cliente primeiro.')));
      return;
    }
    String customerId = customers.first['id'].toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Adicionar cliente — ${route['name']}'),
          content: DropdownButtonFormField<String>(
            initialValue: customerId,
            items: [for (final customer in customers) DropdownMenuItem(value: customer['id'].toString(), child: Text(customer['name']?.toString() ?? 'Cliente'))],
            onChanged: (value) => setDialog(() => customerId = value ?? customerId),
            decoration: const InputDecoration(labelText: 'Cliente'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                try {
                  await repo.assignCustomerToRoute(routeId: route['id'].toString(), customerId: customerId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  refresh();
                } catch (e) {
                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> removeMember(String routeId, String customerId) async {
    try {
      await repo.removeCustomerFromRoute(routeId: routeId, customerId: customerId);
      refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> removeRoute(Map<String, dynamic> route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir rota?'),
        content: const Text('Os clientes não serão excluídos; apenas a rota e seus vínculos serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteRoute(route['id'].toString());
      refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível excluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rotas de cobrança')),
      floatingActionButton: FloatingActionButton(onPressed: routeForm, child: const Icon(Icons.add)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) return const Center(child: Text('Nenhuma rota cadastrada.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final route = rows[index];
              final members = List<Map<String, dynamic>>.from((route['cobrapp_customer_routes'] as List?) ?? const []);
              return Card(
                child: ExpansionTile(
                  title: Text(route['name']?.toString() ?? ''),
                  subtitle: Text('${members.length} cliente(s)${(route['description'] ?? '').toString().isNotEmpty ? ' • ${route['description']}' : ''}'),
                  children: [
                    for (final member in members)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(relationMap(member['cobrapp_customers'])?['name']?.toString() ?? 'Cliente'),
                        subtitle: Text([relationMap(member['cobrapp_customers'])?['phone'], relationMap(member['cobrapp_customers'])?['address']].where((v) => v != null && v.toString().isNotEmpty).join(' • ')),
                        trailing: IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => removeMember(route['id'].toString(), member['customer_id'].toString())),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                      child: Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => assign(route), icon: const Icon(Icons.person_add_alt_1), label: const Text('Adicionar cliente'))),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') routeForm(existing: route);
                            if (value == 'delete') removeRoute(route);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Excluir')),
                          ],
                        ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final repo = CobrAppRepository();
  final name = TextEditingController();
  final phone = TextEditingController();
  final business = TextEditingController();
  String currency = 'BRL';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    business.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final profile = await repo.profile();
      if (profile != null) {
        name.text = profile['name']?.toString() ?? '';
        phone.text = profile['phone']?.toString() ?? '';
        business.text = profile['business_name']?.toString() ?? '';
        currency = profile['currency']?.toString() ?? 'BRL';
      } else {
        name.text = repo.db.auth.currentUser?.email?.split('@').first ?? '';
      }
    } catch (_) {
      // Perfil é opcional; mantém a tela utilizável.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      await repo.saveProfile(name: name.text.trim(), phone: phone.text.trim(), businessName: business.text.trim(), currency: currency);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Perfil', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline))),
                        const SizedBox(height: 10),
                        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', prefixIcon: Icon(Icons.phone_outlined))),
                        const SizedBox(height: 10),
                        TextField(controller: business, decoration: const InputDecoration(labelText: 'Nome do negócio', prefixIcon: Icon(Icons.store_outlined))),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: currency,
                          items: const [
                            DropdownMenuItem(value: 'BRL', child: Text('Real brasileiro (R\$)')),
                            DropdownMenuItem(value: 'USD', child: Text('Dólar (US\$)')),
                            DropdownMenuItem(value: 'EUR', child: Text('Euro (€)')),
                          ],
                          onChanged: (value) => setState(() => currency = value ?? 'BRL'),
                          decoration: const InputDecoration(labelText: 'Moeda', prefixIcon: Icon(Icons.currency_exchange)),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: saving ? null : save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(saving ? 'Salvando...' : 'Salvar perfil'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(child: ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Conta'), subtitle: Text(repo.db.auth.currentUser?.email ?? ''))),
                const SizedBox(height: 12),
                const Card(child: ListTile(leading: Icon(Icons.security_outlined), title: Text('Dados e segurança'), subtitle: Text('Os dados são isolados pelo usuário autenticado no Supabase.'))),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => repo.db.auth.signOut(), icon: const Icon(Icons.logout), label: const Text('Sair da conta')),
              ],
            ),
    );
  }
}
