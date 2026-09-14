import 'package:flutter/material.dart';

import 'calculator_page.dart';
import 'collaborators_page.dart';
import 'company_settings_page.dart';
import 'customers_page.dart';
import 'data/auth_repository.dart';
import 'documents_page.dart';
import 'expenses_page.dart';
import 'legacy_app.dart' as legacy;
import 'loans_page.dart';
import 'notifications_page.dart';
import 'notifications_repository.dart';
import 'payments_page.dart';
import 'portfolio_page.dart';
import 'premium_page.dart';
import 'reports_page.dart';
import 'routes_tags_page.dart';
import 'support_help_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final auth = AuthRepository();
  final notifications = NotificationsRepository();
  Future<int>? unreadFuture;

  @override
  void initState() {
    super.initState();
    unreadFuture = notifications.unreadCount();
    _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    try {
      await notifications.syncAndSendEmails();
    } catch (_) {}
    _refreshUnread();
  }

  void _refreshUnread() {
    if (!mounted) return;
    setState(() => unreadFuture = notifications.unreadCount());
  }

  Widget denied(String area) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 12),
              const Text(
                'Acesso negado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Este colaborador não possui permissão para acessar $area.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget guarded(String area, Widget child) =>
      auth.hasAreaAccess(area) ? child : denied(area);

  Widget page() {
    switch (tab) {
      case 1:
        return guarded('customers', const CustomersPage());
      case 2:
        return guarded('loans', const LoansPage());
      case 3:
        return const legacy.CollectionPage();
      case 4:
        return guarded('expenses', const ExpensesPage());
      case 5:
        return guarded('payments', const PaymentsPage());
      case 6:
        return const legacy.ReceiptsPage();
      case 7:
        return guarded('routes', const RoutesTagsPage());
      case 8:
        return guarded('reports', const ReportsPage());
      case 9:
        return const PortfolioPage();
      case 10:
        return const CalculatorPage();
      case 11:
        return guarded('settings', const CompanySettingsPage());
      case 12:
        return auth.isCollaborator
            ? denied('gerenciamento de colaboradores')
            : const CollaboratorsPage();
      case 13:
        return guarded('documents', const DocumentsPage());
      case 14:
        return guarded(
          'payments',
          NotificationsPage(onChanged: _refreshUnread),
        );
      case 15:
        return const SupportHelpPage();
      case 16:
        return auth.isCollaborator
            ? denied('assinatura Premium')
            : const PremiumPage();
      default:
        return const legacy.DashboardPage();
    }
  }

  bool get _useEnhancedButtons =>
      const {1, 2, 4, 5, 7, 8, 11, 12, 13, 14, 15, 16}.contains(tab);

  Widget _withEnhancedButtons(Widget child) {
    if (!_useEnhancedButtons) return child;

    final base = Theme.of(context);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return Theme(
      data: base.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFF3B2A5A);
              }
              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFFA855F7);
              }
              return const Color(0xFF7C3AED);
            }),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            overlayColor: const WidgetStatePropertyAll(Color(0x33EC4899)),
            elevation: const WidgetStatePropertyAll(2),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
            shape: WidgetStatePropertyAll(rounded),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFF8B5CF6)),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            overlayColor: const WidgetStatePropertyAll(Color(0x33EC4899)),
            elevation: const WidgetStatePropertyAll(3),
            shape: WidgetStatePropertyAll(rounded),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF0ABFC)),
            backgroundColor: const WidgetStatePropertyAll(Color(0x221E1B4B)),
            side: WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.pressed)
                  ? const Color(0xFFF472B6)
                  : const Color(0xFFEC4899);
              return BorderSide(color: color, width: 1.4);
            }),
            overlayColor: const WidgetStatePropertyAll(Color(0x337C3AED)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            shape: WidgetStatePropertyAll(rounded),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFC4B5FD)),
            overlayColor: const WidgetStatePropertyAll(Color(0x227C3AED)),
            shape: WidgetStatePropertyAll(rounded),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFFF0ABFC)),
            overlayColor: const WidgetStatePropertyAll(Color(0x227C3AED)),
            shape: WidgetStatePropertyAll(rounded),
          ),
        ),
      ),
      child: child,
    );
  }

  void select(int index) {
    Navigator.of(context).pop();
    setState(() => tab = index);
    if (index == 14) _syncNotifications();
  }

  Widget notificationButton() {
    return FutureBuilder<int>(
      future: unreadFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notificações',
          onPressed: () {
            setState(() => tab = 14);
            _syncNotifications();
          },
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawer(
        selectedIndex: tab,
        onDestinationSelected: select,
        header: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Roots Cobrança',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        children: const [
          NavigationDrawerDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Início')),
          NavigationDrawerDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Clientes')),
          NavigationDrawerDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Empréstimos')),
          NavigationDrawerDestination(icon: Icon(Icons.event_available_outlined), selectedIcon: Icon(Icons.event_available), label: Text('Cobranças')),
          NavigationDrawerDestination(icon: Icon(Icons.money_off_outlined), selectedIcon: Icon(Icons.money_off), label: Text('Despesas')),
          Divider(indent:16,endIndent:16),
          NavigationDrawerDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Pagamentos')),
          NavigationDrawerDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: Text('Recibos')),
          NavigationDrawerDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: Text('Rotas')),
          NavigationDrawerDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Relatórios')),
          NavigationDrawerDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: Text('Gestão da Carteira')),
          NavigationDrawerDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: Text('Calculadora')),
          NavigationDrawerDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Configurações')),
          NavigationDrawerDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: Text('Colaboradores')),
          NavigationDrawerDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: Text('Documentos')),
          NavigationDrawerDestination(icon: Icon(Icons.notifications_none_outlined), selectedIcon: Icon(Icons.notifications), label: Text('Notificações')),
          NavigationDrawerDestination(icon: Icon(Icons.help_outline), selectedIcon: Icon(Icons.help), label: Text('Ajuda')),
          NavigationDrawerDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: Text('Premium')),
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
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)]),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 11),
            const Text('Roots Cobrança', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Premium',
            onPressed: auth.isCollaborator ? null : () => setState(() => tab = 16),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          notificationButton(),
          IconButton(tooltip: 'Sair', onPressed: () => auth.signOut(), icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: SafeArea(child: _withEnhancedButtons(page())),
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
          NavigationDestination(icon: Icon(Icons.money_off_outlined), selectedIcon: Icon(Icons.money_off), label: 'Despesas'),
        ],
      ),
    );
  }
}
