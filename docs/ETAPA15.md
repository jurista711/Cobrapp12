# Etapa 15 — Revisão geral e preparação para APK

Revisão geral da reconstrução até a Etapa 14, com correções de integração encontradas na inspeção final.

## Correções finais
- Exportação CSV corrigida: gera arquivo `.csv` real, com BOM UTF-8 e compartilhamento como arquivo.
- Recibo corrigido: `nextval()` reserva o número antes de montar o texto e o mesmo número é gravado no registro, evitando falha de `currval()` em sessão nova.
- Relatório por cliente corrigido: recebimentos passam a ser agregados por `customer_id`.
- Mantidos Supabase Auth, RLS e isolamento por `auth.uid()`.
- Mantidos clientes, empréstimos, parcelas, pagamentos, pagamento parcial, somente juros, juros de atraso, recibos, caixa, rotas, relatórios, telefone/WhatsApp e configurações.

## Verificações
- ZIP da Etapa 14 extraído sem erro.
- Estrutura Flutter e dependências conferidas.
- Referências entre `main.dart`, `cobrapp_repository.dart` e `supabase_schema.sql` revisadas.
- ZIP final testado com `unzip -t` sem erros.

## Limitação de build
O ambiente atual não possui Flutter/Android SDK configurado para executar `flutter analyze` e `flutter build apk`. Portanto, esta etapa prepara e revisa o projeto, mas não afirma que um APK foi compilado aqui.

## Próximo passo
Executar o `supabase_schema.sql` no projeto Supabase e abrir o projeto em um ambiente com Flutter/Android SDK para gerar o APK e fazer o teste no Android.
