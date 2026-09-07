# CobrApp Supabase — Etapa 5

Avanço desta etapa:
- cadastro de clientes com endereço e observações;
- edição de cliente;
- exclusão de cliente com confirmação;
- dashboard com valores em aberto e em atraso;
- manutenção do fluxo de empréstimos, parcelas e pagamentos da Etapa 4;
- dados continuam isolados por `auth.uid()` com RLS.

A exclusão de cliente usa as chaves estrangeiras com `on delete cascade` definidas no schema, portanto os empréstimos/parcelas relacionados também são removidos.

Esta é uma reconstrução independente baseada no comportamento observável e no inventário do APK original. Ainda não é uma cópia 1:1 de todas as telas e regras do aplicativo original.
