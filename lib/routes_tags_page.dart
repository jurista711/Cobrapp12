import 'package:flutter/material.dart';

import 'routes_repository.dart';

class RoutesTagsPage extends StatefulWidget {
  const RoutesTagsPage({super.key});

  @override
  State<RoutesTagsPage> createState() => _RoutesTagsPageState();
}

class _RoutesTagsPageState extends State<RoutesTagsPage> {
  final repo = RoutesRepository();
  bool loading = true;
  List<Map<String, dynamic>> routes = [];
  List<Map<String, dynamic>> collaborators = [];
  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> tags = [];
  List<Map<String, dynamic>> links = [];
  String tagFilter = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        repo.routes(),
        repo.collaborators(),
        repo.customers(),
        repo.tags(),
        repo.customerTagLinks(),
      ]);
      if (!mounted) return;
      setState(() {
        routes = List<Map<String, dynamic>>.from(values[0]);
        collaborators = List<Map<String, dynamic>>.from(values[1]);
        customers = List<Map<String, dynamic>>.from(values[2]);
        tags = List<Map<String, dynamic>>.from(values[3]);
        links = List<Map<String, dynamic>>.from(values[4]);
        loading = false;
        if (tagFilter.isNotEmpty && !tags.any((e) => e['id'].toString() == tagFilter)) {
          tagFilter = '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar rotas e etiquetas: $e')));
    }
  }

  Color colorOf(String? hex) {
    final value = hex ?? '#7C3AED';
    try {
      return Color(int.parse(value.replaceFirst('#', '0xff')));
    } catch (_) {
      return const Color(0xFF7C3AED);
    }
  }

  String collaboratorName(String? id) {
    if (id == null || id.isEmpty) return 'Sem colaborador atribuído';
    for (final row in collaborators) {
      if (row['id'].toString() == id) return row['name']?.toString() ?? 'Colaborador';
    }
    return 'Colaborador';
  }

  Set<String> tagsForCustomer(String customerId) => links
      .where((e) => e['customer_id'].toString() == customerId)
      .map((e) => e['tag_id'].toString())
      .toSet();

  Future<void> editRoute([Map<String, dynamic>? route]) async {
    final name = TextEditingController(text: route?['name']?.toString() ?? '');
    final region = TextEditingController(text: route?['region']?.toString() ?? '');
    final areas = TextEditingController(
      text: route == null ? '' : List<String>.from(route['areas'] ?? const <String>[]).join(', '),
    );
    String collaboratorId = route?['collaborator_id']?.toString() ?? '';
    final selectedCustomers = customers
        .where((e) => e['route_id']?.toString() == route?['id']?.toString())
        .map((e) => e['id'].toString())
        .toSet();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(route == null ? 'Criar Rota' : 'Editar Rota'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome da rota', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: region, decoration: const InputDecoration(labelText: 'Região', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: areas, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Bairros ou cidades atendidas', hintText: 'Separe por vírgulas', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: collaboratorId,
                    decoration: const InputDecoration(labelText: 'Colaborador responsável', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Sem colaborador atribuído')),
                      ...collaborators.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['name']?.toString() ?? 'Colaborador'))),
                    ],
                    onChanged: (value) => setDialogState(() => collaboratorId = value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  const Text('Associar clientes à rota', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  if (customers.isEmpty)
                    const Text('Nenhum cliente cadastrado.')
                  else
                    ...customers.map((customer) {
                      final id = customer['id'].toString();
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(customer['name']?.toString() ?? 'Cliente'),
                        subtitle: Text(customer['document']?.toString() ?? ''),
                        value: selectedCustomers.contains(id),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selectedCustomers.add(id);
                          } else {
                            selectedCustomers.remove(id);
                          }
                        }),
                      );
                    }),
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
                      if (name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Informe o nome da rota.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await repo.saveRoute(
                          id: route?['id']?.toString(),
                          name: name.text,
                          region: region.text,
                          areas: areas.text.split(','),
                          collaboratorId: collaboratorId.isEmpty ? null : collaboratorId,
                          customerIds: selectedCustomers.toList(),
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await load();
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Erro ao salvar rota: $e')));
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    region.dispose();
    areas.dispose();
  }

  Future<void> showRouteCustomers(Map<String, dynamic> route) async {
    final rows = await repo.customersByRoute(route['id'].toString());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clientes por Rota — ${route['name']}'),
        content: SizedBox(
          width: 520,
          child: rows.isEmpty
              ? const Text('Nenhum cliente associado a esta rota.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final customer = rows[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(customer['name']?.toString() ?? 'Cliente'),
                      subtitle: Text([customer['document'], customer['phone']].where((e) => e != null && e.toString().isNotEmpty).join(' • ')),
                    );
                  },
                ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }

  Future<void> editTag([Map<String, dynamic>? tag]) async {
    final name = TextEditingController(text: tag?['name']?.toString() ?? '');
    final color = TextEditingController(text: tag?['color']?.toString() ?? '#7C3AED');
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tag == null ? 'Criar Etiqueta' : 'Editar Etiqueta'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome da etiqueta', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                  controller: color,
                  decoration: InputDecoration(
                    labelText: 'Cor hexadecimal',
                    hintText: '#7C3AED',
                    border: const OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(radius: 12, backgroundColor: colorOf(color.text)),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final tagName = name.text.trim();
                      final tagColor = color.text.trim();
                      if (tagName.isEmpty || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(tagColor)) {
                        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Informe nome e cor no formato #RRGGBB.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        if (tag == null) {
                          await repo.createTag(name: tagName, color: tagColor);
                        } else {
                          await repo.updateTag(id: tag['id'].toString(), name: tagName, color: tagColor);
                        }
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await load();
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Erro ao salvar etiqueta: $e')));
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    color.dispose();
  }

  Future<void> removeTag(Map<String, dynamic> tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Etiqueta?'),
        content: Text('Deseja excluir a etiqueta "${tag['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await repo.deleteTag(tag['id'].toString());
    await load();
  }

  Future<void> assignCustomerTags(Map<String, dynamic> customer) async {
    final selected = tagsForCustomer(customer['id'].toString());
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Etiquetas — ${customer['name']}'),
          content: SizedBox(
            width: 500,
            child: tags.isEmpty
                ? const Text('Crie uma etiqueta antes de atribuí-la ao cliente.')
                : ListView(
                    shrinkWrap: true,
                    children: tags.map((tag) {
                      final id = tag['id'].toString();
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: CircleAvatar(radius: 11, backgroundColor: colorOf(tag['color']?.toString())),
                        title: Text(tag['name']?.toString() ?? 'Etiqueta'),
                        value: selected.contains(id),
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(
              onPressed: saving || tags.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      await repo.assignTags(customerId: customer['id'].toString(), tagIds: selected.toList());
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      await load();
                    },
              child: Text(saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget routesTab() => RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Rotas de Atendimento', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                FilledButton.icon(onPressed: () => editRoute(), icon: const Icon(Icons.add_road), label: const Text('Criar Rota')),
              ],
            ),
            const SizedBox(height: 12),
            if (routes.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma rota cadastrada.'))),
            ...routes.map((route) {
              final areas = List<String>.from(route['areas'] ?? const <String>[]);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route_outlined),
                          const SizedBox(width: 10),
                          Expanded(child: Text(route['name']?.toString() ?? 'Rota', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                          IconButton(tooltip: 'Editar Rota', onPressed: () => editRoute(route), icon: const Icon(Icons.edit_outlined)),
                        ],
                      ),
                      if ((route['region']?.toString() ?? '').isNotEmpty) Text('Região: ${route['region']}'),
                      if (areas.isNotEmpty) Text('Bairros/Cidades: ${areas.join(', ')}'),
                      Text('Responsável: ${collaboratorName(route['collaborator_id']?.toString())}'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => showRouteCustomers(route),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Clientes por Rota'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );

  Widget tagsTab() {
    final filteredCustomers = tagFilter.isEmpty
        ? customers
        : customers.where((customer) => tagsForCustomer(customer['id'].toString()).contains(tagFilter)).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(child: Text('Gerenciar Etiquetas', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
              FilledButton.icon(onPressed: () => editTag(), icon: const Icon(Icons.new_label_outlined), label: const Text('Criar Etiqueta')),
            ],
          ),
          const SizedBox(height: 12),
          if (tags.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('Nenhuma etiqueta cadastrada.')))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => InputChip(
                    avatar: CircleAvatar(backgroundColor: colorOf(tag['color']?.toString())),
                    label: Text(tag['name']?.toString() ?? 'Etiqueta'),
                    onPressed: () => editTag(tag),
                    onDeleted: () => removeTag(tag),
                  )).toList(),
            ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: tagFilter,
            decoration: const InputDecoration(labelText: 'Filtrar clientes por etiqueta', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos os clientes')),
              ...tags.map((tag) => DropdownMenuItem(value: tag['id'].toString(), child: Text(tag['name']?.toString() ?? 'Etiqueta'))),
            ],
            onChanged: (value) => setState(() => tagFilter = value ?? ''),
          ),
          const SizedBox(height: 12),
          const Text('Atribuir Etiquetas a Clientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (filteredCustomers.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Nenhum cliente encontrado para este filtro.'))),
          ...filteredCustomers.map((customer) {
            final ids = tagsForCustomer(customer['id'].toString());
            final customerTags = tags.where((tag) => ids.contains(tag['id'].toString())).toList();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(customer['name']?.toString() ?? 'Cliente'),
                subtitle: customerTags.isEmpty
                    ? const Text('Sem etiquetas')
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: customerTags.map((tag) => Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: CircleAvatar(backgroundColor: colorOf(tag['color']?.toString())),
                              label: Text(tag['name']?.toString() ?? 'Etiqueta'),
                            )).toList(),
                      ),
                trailing: IconButton(tooltip: 'Atribuir etiquetas', onPressed: () => assignCustomerTags(customer), icon: const Icon(Icons.sell_outlined)),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.route_outlined), text: 'Rotas'),
              Tab(icon: Icon(Icons.sell_outlined), text: 'Etiquetas'),
            ],
          ),
          Expanded(child: TabBarView(children: [routesTab(), tagsTab()])),
        ],
      ),
    );
  }
}
