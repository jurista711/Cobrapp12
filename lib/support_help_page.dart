import 'package:flutter/material.dart';

class SupportHelpPage extends StatelessWidget {
  const SupportHelpPage({super.key});

  void _open(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String body,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context, title, body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Centro de Ajuda',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tutoriais e guias organizados por categoria.',
        ),
        const SizedBox(height: 16),
        _item(
          context,
          icon: Icons.help_center_outlined,
          title: 'Centro de Ajuda',
          subtitle: 'Página central com todos os tutoriais e guias do sistema',
          body: 'Use as categorias desta tela para acessar os tutoriais de colaboradores, controle de despesas, configurações da empresa e documentos.\n\nGlossário:\nCliente: pessoa ou empresa cadastrada no sistema.\nEmpréstimo: operação registrada para um cliente.\nParcela: parte do valor do empréstimo com vencimento definido.\nPagamento: valor registrado para quitar total ou parcialmente uma obrigação.\nRota: agrupamento de clientes para organização de atendimento.\nEtiqueta: classificação usada para organizar clientes.',
        ),
        _item(
          context,
          icon: Icons.manage_accounts_outlined,
          title: 'Ajuda de Colaboradores',
          subtitle: 'Tutorial específico sobre gerenciamento de colaboradores',
          body: '1. Abra Colaboradores.\n2. Use Novo Colaborador para cadastrar nome, e-mail, senha inicial e nível de acesso.\n3. Defina as permissões por área.\n4. Associe uma rota quando necessário.\n5. Salve as alterações.\n6. Use a edição para atualizar permissões, cargo, acesso ou status.',
        ),
        _item(
          context,
          icon: Icons.money_off_outlined,
          title: 'Ajuda de Controle de Despesas',
          subtitle: 'Tutorial específico sobre controle de gastos',
          body: '1. Abra Despesas.\n2. Registre uma nova despesa com descrição, categoria, valor, data e observações.\n3. Use os filtros por período, categoria, valor ou status.\n4. Edite ou exclua uma despesa quando necessário.\n5. Consulte o relatório de despesas para analisar os gastos por período ou categoria.',
        ),
        _item(
          context,
          icon: Icons.business_outlined,
          title: 'Ajuda da Empresa',
          subtitle: 'Tutorial específico sobre configurações da empresa',
          body: '1. Abra Configurações.\n2. Preencha os dados básicos da empresa.\n3. Envie logotipo e assinatura.\n4. Configure juros de mora e multa por atraso.\n5. Habilite as formas de pagamento aceitas.\n6. Salve as configurações.',
        ),
        _item(
          context,
          icon: Icons.description_outlined,
          title: 'Ajuda de Documentos',
          subtitle: 'Tutorial específico sobre modelos de documentos',
          body: '1. Abra Documentos.\n2. Crie ou edite um modelo.\n3. Escolha o tipo do documento.\n4. Selecione cliente e empréstimo para preencher os dados disponíveis.\n5. Revise o texto.\n6. Inclua assinaturas quando aplicável.\n7. Gere o documento final.',
        ),
        _item(
          context,
          icon: Icons.gavel_outlined,
          title: 'Termos de Uso',
          subtitle: 'Página com os termos de serviço do sistema',
          body: 'O documento oficial do projeto define esta área como a página de Termos de Uso, destinada às regras de utilização do sistema. O texto jurídico definitivo dos termos não foi fornecido nas especificações atuais.',
        ),
        _item(
          context,
          icon: Icons.privacy_tip_outlined,
          title: 'Política de Privacidade',
          subtitle: 'Página com a política de privacidade e tratamento de dados',
          body: 'O documento oficial do projeto define esta área como a página de Política de Privacidade, destinada a explicar como os dados são tratados. O texto jurídico definitivo da política não foi fornecido nas especificações atuais.',
        ),
        _item(
          context,
          icon: Icons.info_outline,
          title: 'Sobre o Sistema',
          subtitle: 'Informações sobre a versão do app e dados técnicos',
          body: 'Roots Cobrança\nProjeto: Berlan Roots\nVersão: 1.0.0+1\nPlataforma: Flutter / Dart\nStatus: em desenvolvimento conforme documento oficial de especificações.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
