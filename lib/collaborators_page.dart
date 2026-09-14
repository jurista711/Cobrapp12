import 'package:flutter/material.dart';

import 'collaborators_repository.dart';

class CollaboratorsPage extends StatefulWidget {
  const CollaboratorsPage({super.key});

  @override
  State<CollaboratorsPage> createState() => _CollaboratorsPageState();
}

class _CollaboratorsPageState extends State<CollaboratorsPage> {
  final repo = CollaboratorsRepository();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> rows = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      rows = await repo.all();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Map<String, bool> defaultsForRole(String role) {
    if (role == 'admin') {
      return {for (final a in _areas) a: true};
    }
    if (role == 'manager') {
      return {
        'customers': true,
        'loans': true,
        'payments': true,
        'reports': true,
        'expenses': false,
        'documents': false,
        'settings': false,
        'routes': false,
      };
    }
    return {
      'customers': true,
      'loans': false,
      'payments': true,
      'reports': false,
      'expenses': false,
      'documents': false,
      'settings': false,
      'routes': false,
    };
  }

  static const _areas = [
    'customers','loans','payments','reports','expenses','documents','settings','routes'
  ];
  static const _labels = {
    'customers':'Clientes','loans':'Empréstimos','payments':'Pagamentos','reports':'Relatórios',
    'expenses':'Despesas','documents':'Documentos','settings':'Configurações','routes':'Rotas'
  };

  Future<void> edit([Map<String, dynamic>? row]) async {
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    final email = TextEditingController(text: row?['email']?.toString() ?? '');
    final password = TextEditingController();
    final route = TextEditingController(text: row?['route_name']?.toString() ?? '');
    var role = row?['role']?.toString() ?? 'operational';
    var active = row?['is_active'] != false;
    final currentPerms = row?['permissions'];
    var permissions = currentPerms is Map
        ? {for (final a in _areas) a: currentPerms[a] == true}
        : defaultsForRole(role);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(row == null ? 'Adicionar Colaborador' : 'Editar Colaborador'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome completo')),
                  const SizedBox(height: 10),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail')),
                  const SizedBox(height: 10),
                  TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: row == null ? 'Senha inicial' : 'Nova senha (opcional)')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Nível de permissão'),
                    items: const [
                      DropdownMenuItem(value:'admin',child:Text('Administrador')),
                      DropdownMenuItem(value:'manager',child:Text('Gerente')),
                      DropdownMenuItem(value:'operational',child:Text('Operacional')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLocal(() { role = v; permissions = defaultsForRole(v); });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: route, decoration: const InputDecoration(labelText: 'Rota de atendimento responsável (se aplicável)')),
                  SwitchListTile(value: active, onChanged: (v)=>setLocal(()=>active=v), title: const Text('Status: Ativo')),
                  const Divider(),
                  const Align(alignment: Alignment.centerLeft, child: Text('Permissões específicas', style: TextStyle(fontWeight: FontWeight.w800))),
                  for (final area in _areas)
                    CheckboxListTile(
                      dense: true,
                      value: permissions[area] == true,
                      onChanged: role == 'admin' ? null : (v)=>setLocal(()=>permissions[area]=v==true),
                      title: Text(_labels[area]!),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar')),
            FilledButton(onPressed: ()=>Navigator.pop(context,true), child: Text(row == null ? 'Salvar' : 'Editar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (row == null) {
        await repo.add(name:name.text,email:email.text,password:password.text,role:role,permissions:permissions,routeName:route.text,active:active);
      } else {
        await repo.update(id:row['id'].toString(),name:name.text,email:email.text,password:password.text,role:role,permissions:permissions,routeName:route.text,active:active);
      }
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> toggle(Map<String,dynamic> row) async {
    final currentPerms = row['permissions'];
    final permissions = currentPerms is Map
        ? {for (final a in _areas) a: currentPerms[a] == true}
        : defaultsForRole(row['role']?.toString() ?? 'operational');
    await repo.update(
      id: row['id'].toString(), name: row['name'].toString(), email: row['email'].toString(),
      role: row['role'].toString(), permissions: permissions, routeName: row['route_name']?.toString(),
      active: row['is_active'] == false,
    );
    await load();
  }

  void tutorial() {
    showDialog<void>(context: context, builder: (context)=>AlertDialog(
      title: const Text('Tutorial de Gerenciamento de Colaboradores'),
      content: const Text('1. Toque em “Novo Colaborador”.\n2. Informe nome, e-mail e senha inicial.\n3. Escolha Administrador, Gerente ou Operacional.\n4. Ajuste as permissões específicas por área.\n5. Informe a rota de atendimento, se aplicável.\n6. Salve. Depois, use Editar para atualizar dados, cargo ou acesso e Desativar para bloquear o colaborador.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context), child:const Text('Fechar'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child:CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children:[
            const Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Colaboradores',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
              Text('Gerencie usuários, níveis de acesso e permissões.'),
            ])),
            IconButton(tooltip:'Tutorial',onPressed:tutorial,icon:const Icon(Icons.help_outline)),
            const SizedBox(width:8),
            FilledButton.icon(onPressed:()=>edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('Novo Colaborador')),
          ]),
          const SizedBox(height:16),
          if (error != null) Card(child:Padding(padding:const EdgeInsets.all(16),child:Text(error!))),
          if (rows.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('Nenhum colaborador cadastrado.'))),
          for (final row in rows)
            Card(
              margin: const EdgeInsets.only(bottom:10),
              child: ListTile(
                leading: CircleAvatar(child:Text((row['name']?.toString() ?? '?').substring(0,1).toUpperCase())),
                title: Text(row['name']?.toString() ?? ''),
                subtitle: Text('${row['email']} • ${_roleLabel(row['role'])} • ${row['is_active'] == false ? 'Inativo' : 'Ativo'}${row['route_name'] == null ? '' : ' • Rota: ${row['route_name']}'}'),
                trailing: Wrap(spacing:4,children:[
                  IconButton(tooltip:'Editar Colaborador',onPressed:()=>edit(row),icon:const Icon(Icons.edit_outlined)),
                  IconButton(tooltip:row['is_active']==false?'Reativar':'Desativar',onPressed:()=>toggle(row),icon:Icon(row['is_active']==false?Icons.person_add_alt:Icons.person_off_outlined)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  static String _roleLabel(dynamic value) {
    switch(value?.toString()) {
      case 'admin': return 'Administrador';
      case 'manager': return 'Gerente';
      default: return 'Operacional';
    }
  }
}
