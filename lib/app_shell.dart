import 'package:flutter/material.dart';

import 'calculator_page.dart';
import 'collaborators_page.dart';
import 'customers_page.dart';
import 'data/auth_repository.dart';
import 'expenses_page.dart';
import 'legacy_app.dart' as legacy;
import 'loans_page.dart';
import 'payments_page.dart';
import 'portfolio_page.dart';
import 'reports_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final auth = AuthRepository();

  Widget denied(String area) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 12),
            const Text('Acesso negado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Este colaborador não possui permissão para acessar $area.', textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget guarded(String area, Widget child) => auth.hasAreaAccess(area) ? child : denied(area);

  Widget page() {
    switch (tab) {
      case 1:
        return guarded('customers', const CustomersPage());
      case 2:
        return guarded('loans', const LoansPage());
      case 3:
        return const legacy.CollectionPage();
      case 4:
        return const legacy.CashPage();
      case 5:
        return guarded('payments', const PaymentsPage());
      case 6:
        return const legacy.ReceiptsPage();
      case 7:
        return guarded('routes', const legacy.RoutesPage());
      case 8:
        return guarded('reports', const ReportsPage());
      case 9:
        return const PortfolioPage();
      case 10:
        return const CalculatorPage();
      case 11:
        return guarded('settings', const legacy.SettingsPage());
      case 12:
        return auth.isCollaborator ? denied('gerenciamento de colaboradores') : const CollaboratorsPage();
      case 13:
        return guarded('expenses', const ExpensesPage());
      default:
        return const legacy.DashboardPage();
    }
  }

  void select(int index) {
    Navigator.of(context).pop();
    setState(() => tab = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: tab,
        onDestinationSelected: select,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7)])),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(child: Text('Roots Cobrança', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          ]),
        ),
        children: const [
          NavigationDrawerDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Início')),
          NavigationDrawerDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Clientes')),
          NavigationDrawerDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Empréstimos')),
          NavigationDrawerDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: Text('Cobranças')),
          NavigationDrawerDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: Text('Caixa')),
          Divider(indent: 16, endIndent: 16),
          NavigationDrawerDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Pagamentos')),
          NavigationDrawerDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Recibos')),
          NavigationDrawerDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: Text('Rotas')),
          NavigationDrawerDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Relatórios')),
          NavigationDrawerDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: Text('Gestão da Carteira')),
          NavigationDrawerDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: Text('Calculadora')),
          NavigationDrawerDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Configurações')),
          NavigationDrawerDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: Text('Colaboradores')),
          NavigationDrawerDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Despesas')),
        ],
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFBE185D), Color(0xFFEF233C)]),
          ),
        ),
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)])),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 11),
          const Text('Roots Cobrança', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
        ]),
        actions: [IconButton(tooltip: 'Sair', onPressed: () => auth.signOut(), icon: const Icon(Icons.logout_rounded))],
      ),
      body: SafeArea(child: page()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab > 4 ? 0 : tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        backgroundColor: const Color(0xFF120A2B),
        elevation: 12,
        indicatorColor: const Color(0xFF9D174D),
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Empréstimos'),
          NavigationDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: 'Cobranças'),
          NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: 'Caixa'),
        ],
      ),
    );
  }
}
