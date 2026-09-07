# Correção do build Flutter — CobrApp

Correções aplicadas após o `flutter analyze` do GitHub Actions.

## 1. pubspec.yaml
- `share_plus` atualizado de `^9.0.0` para `^12.0.2` para eliminar o conflito de `web` com `file_picker ^8.3.7`.

## 2. lib/main.dart
- Refeito o arquivo para remover erros de sintaxe e declarações incompletas.
- Restaurados os helpers `money`, `StatCard`, `openWhatsApp`, `openPhone`, `collectionMessage` e `saldoFor`.
- Corrigidas as páginas de dashboard, clientes, empréstimos, pagamentos, cobranças, recibos, caixa, rotas, relatórios e configurações.
- CSV usa arquivo real e `SharePlus.instance.share(ShareParams(...))`.

## 3. lib/data/cobrapp_repository.dart
- Removido `!` desnecessário do usuário autenticado.
- Corrigida comparação de datas `String` usando `compareTo`.
- Corrigidos os `for` sem bloco.
- `portfolioReport` agora busca `customer_id` dos pagamentos e distribui recebimentos por cliente.

## 4. test/widget_test.dart
- Substituído o teste padrão que referenciava `MyApp` por um teste simples do `StatCard`.

## Próximo passo
Substitua os arquivos desta correção no projeto do GitHub/Android IDE e rode novamente o workflow `flutter analyze --no-fatal-infos` antes de tentar gerar o APK.
