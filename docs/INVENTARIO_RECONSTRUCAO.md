# CobrApp / PrestApp — reconstrução para Supabase

## Fonte analisada
APK Flutter compilado: `com.yibsonalexis.prestapp`.

A análise do `libapp.so` revelou a arquitetura lógica original, incluindo:

- `data/firebase/impl_customers.dart`
- `data/firebase/impl_dashboard.dart`
- `data/firebase/impl_loans.dart`
- `data/firebase/impl_login.dart`
- `data/firebase/impl_payments.dart`
- `data/firebase/impl_overdue_interests.dart`
- `data/firebase/impl_expense_category.dart`
- `data/firebase/impl_expense_detail.dart`
- `data/firebase/impl_expense_route.dart`
- `data/firebase/impl_collection_activities.dart`
- `data/firebase/impl_document_templates.dart`
- `data/firebase/impl_file_storage.dart`
- `data/firebase/impl_tags.dart`
- `data/firebase/impl_user.dart`

Entidades detectadas:

- customer
- customer payment status
- loan
- payment
- interest
- late fee
- expense category/detail/route
- collection activity
- tags
- document template
- user/company/currency

Serviços detectados:

- amortization
- payment calculator
- late fee handler
- loan handler
- loan totals reconciler
- settled loan detector
- customer route assignment
- customer duplicate/name synchronization
- PDF/document generation
- notifications
- printer
- preferences/cache

## Migração

Firebase Auth → Supabase Auth
Firestore → Supabase Postgres/Data API
Firebase Storage → Supabase Storage
Firebase-specific repositories → repositories Supabase

O aplicativo deve manter a UI/UX do APK original; esta base inicial serve para validar autenticação e a camada Supabase antes da reconstrução de todas as páginas.

## Segurança

Somente a chave publishable é usada no cliente. RLS deve ser ativado em todas as tabelas e as políticas devem limitar os dados ao usuário autenticado. A documentação oficial do Supabase recomenda RLS e privilégios mínimos para o Data API.
