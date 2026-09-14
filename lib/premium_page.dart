import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/auth_repository.dart';
import 'premium_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool loading = true;
  bool actionLoading = false;
  CustomerInfo? info;
  String? error;

  bool get active =>
      PremiumService.runtimePremium || AuthRepository().hasPremiumAccess;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final user = AuthRepository().currentUser;
      if (user != null) {
        await PremiumService.configure(appUserId: user.id);
        info = await PremiumService.refresh();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> buy() async {
    if (PremiumService.apiKey.isEmpty) {
      setState(() {
        error = 'A chave pública do RevenueCat ainda não foi configurada no build.';
      });
      return;
    }
    setState(() {
      actionLoading = true;
      error = null;
    });
    try {
      info = await PremiumService.buyCurrentOffering();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active
                ? 'Premium ativado com sucesso.'
                : 'Compra concluída, aguardando ativação do entitlement Premium.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> restore() async {
    if (PremiumService.apiKey.isEmpty) {
      setState(() {
        error = 'A chave pública do RevenueCat ainda não foi configurada no build.';
      });
      return;
    }
    setState(() {
      actionLoading = true;
      error = null;
    });
    try {
      info = await PremiumService.restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active
                ? 'Assinatura Premium restaurada.'
                : 'Nenhuma assinatura Premium ativa foi encontrada.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> manage() async {
    final url = info?.managementURL;
    if (url == null || url.isEmpty) {
      setState(() => error = 'Não há link de gerenciamento disponível para esta assinatura.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) setState(() => error = 'Não foi possível abrir o gerenciamento da assinatura.');
    }
  }

  Widget benefit(IconData icon, String text) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(text),
      );

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final entitlement = info?.entitlements.active[PremiumService.entitlementId];

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Premium',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(active ? Icons.workspace_premium : Icons.lock_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          active ? 'Premium ativo' : 'Plano gratuito',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entitlement?.expirationDate != null) ...[
                    const SizedBox(height: 8),
                    Text('Vencimento: ${entitlement!.expirationDate}'),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: actionLoading || active ? null : buy,
                    icon: const Icon(Icons.workspace_premium),
                    label: Text(actionLoading ? 'Aguarde...' : 'Ativar Premium Agora'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: actionLoading ? null : restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar Assinatura'),
                  ),
                  if (active) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: actionLoading ? null : manage,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Gerenciar Assinatura'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: actionLoading ? null : manage,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar Assinatura'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Conhecer o Premium',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text('Benefícios Premium'),
                  const SizedBox(height: 8),
                  benefit(Icons.people_alt_outlined, 'Clientes ilimitados'),
                  benefit(Icons.group_outlined, 'Mais de um colaborador'),
                  benefit(Icons.analytics_outlined, 'Relatórios avançados'),
                  benefit(Icons.language_outlined, 'Acesso Web'),
                  benefit(Icons.notifications_active_outlined, 'Lembretes automáticos por e-mail'),
                  benefit(Icons.block_outlined, 'Sem anúncios'),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
