# CobrApp Supabase — Etapa 4

Esta etapa transforma empréstimos em um fluxo real de cobrança: cada empréstimo gera parcelas no banco e pagamentos são registrados de forma transacional via RPC.

## SQL
Execute `supabase_schema.sql` no SQL Editor do Supabase antes de testar.

## Fluxo implementado
1. Criar empréstimo.
2. RPC calcula total com juros e cria todas as parcelas.
3. Tela de empréstimos mostra parcelas e valores pagos.
4. Pagamentos escolhem uma parcela pendente.
5. RPC aceita pagamento parcial ou integral e atualiza a parcela.
6. Quando todas as parcelas de um empréstimo ficam pagas, o empréstimo passa para `paid`.

A camada cliente usa `supabase_flutter`; o acesso fica protegido por Auth + RLS. Consulte a documentação oficial do Supabase para Flutter e RLS.
