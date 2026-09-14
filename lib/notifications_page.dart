import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'notifications_repository.dart';

class NotificationsPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const NotificationsPage({super.key, this.onChanged});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final repo = NotificationsRepository();
  bool loading = true;
  bool unreadOnly = false;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() {
      loading = true;
      error = null;
    });
    try {
      await repo.syncAndSendEmails();
      final data = await repo.all(unreadOnly: unreadOnly);
      if (mounted) setState(() => rows = data);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  IconData iconFor(String type) {
    switch (type) {
      case 'overdue':
        return Icons.warning_amber_rounded;
      case 'upcoming':
        return Icons.schedule_rounded;
      case 'commitment':
        return Icons.handshake_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'loan_paid':
        return Icons.check_circle_outline;
      case 'customer':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> mark(Map<String, dynamic> row, bool read) async {
    await repo.markRead(row['id'].toString(), read);
    await refresh();
  }

  Future<void> markAll() async {
    await repo.markAllRead();
    await refresh();
  }

  Future<void> remove(Map<String, dynamic> row) async {
    await repo.remove(row['id'].toString());
    await refresh();
  }

  String dateText(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return d == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notificações e Lembretes',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Atualizar',
                onPressed: loading ? null : refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(repo.isPremium ? Icons.mark_email_read_outlined : Icons.workspace_premium_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lembretes Automáticos por E-mail', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          repo.isPremium
                              ? 'Plano Premium: lembretes de parcelas próximas ou vencidas são preparados e enviados automaticamente quando o serviço de e-mail está configurado.'
                              : 'Funcionalidade exclusiva do plano Premium.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Somente não lidas'),
                selected: unreadOnly,
                onSelected: (v) {
                  setState(() => unreadOnly = v);
                  refresh();
                },
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : markAll,
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Marcar todas como lidas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro ao carregar notificações: $error'),
              ),
            )
          else if (rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Nenhuma notificação encontrada.')),
              ),
            )
          else
            ...rows.map((row) {
              final read = row['is_read'] == true;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(iconFor(row['type']?.toString() ?? ''))),
                  title: Text(
                    row['title']?.toString() ?? 'Notificação',
                    style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w900),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(row['body']?.toString() ?? ''),
                      const SizedBox(height: 4),
                      Text(dateText(row['created_at']), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'toggle') mark(row, !read);
                      if (value == 'delete') remove(row);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'toggle', child: Text(read ? 'Marcar como não lida' : 'Marcar como lida')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir notificação')),
                    ],
                  ),
                  onTap: read ? null : () => mark(row, true),
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
