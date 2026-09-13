import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/supabase_config.dart';
import 'data/auth_repository.dart';
import 'legacy_app.dart' as legacy;

export 'legacy_app.dart' show StatCard;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await initSupabase();
  runApp(const RootsCobrancaApp());
}

class RootsCobrancaApp extends StatelessWidget {
  const RootsCobrancaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Roots Cobrança',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Nunito',
        scaffoldBackgroundColor: const Color(0xFF0A0618),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          onPrimary: Colors.white,
          secondary: Color(0xFFEC4899),
          onSecondary: Colors.white,
          tertiary: Color(0xFFEF4444),
          onTertiary: Colors.white,
          surface: Color(0xFF120A2B),
          onSurface: Color(0xFFF8F5FF),
          error: Color(0xFFFF5252),
          onError: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF17102F),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthRepository();
    return StreamBuilder<AuthState>(
      stream: auth.authState,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginPage();
        if (kIsWeb && !auth.hasPremiumAccess) {
          return const AccessDeniedPage(
            message: 'O acesso Web é exclusivo do plano Premium.',
          );
        }
        return const legacy.HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível concluir a operação.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> login() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Informe e-mail e senha.');
      return;
    }
    await _run(() async {
      await AuthRepository().signIn(email.text.trim(), password.text);
    });
  }

  Future<void> google() async {
    await _run(() async {
      final started = await AuthRepository().signInWithGoogle();
      if (!started) throw const AuthException('Não foi possível iniciar o login com Google.');
    });
  }

  Future<void> apple() async {
    await _run(() async {
      final started = await AuthRepository().signInWithApple();
      if (!started) throw const AuthException('Não foi possível iniciar o login com Apple.');
    });
  }

  Future<void> forgotPassword() async {
    final controller = TextEditingController(text: email.text.trim());
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Recuperação de senha'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Enviar link'),
            ),
          ],
        ),
      );
      if (value == null || value.isEmpty || !mounted) return;
      await _run(() async {
        await AuthRepository().resetPassword(value);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link de redefinição enviado por e-mail.')),
          );
        }
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> createAccount() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CreateAccountPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 76),
                  const SizedBox(height: 12),
                  const Text(
                    'Roots Cobrança',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => loading ? null : login(),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : login,
                      child: Text(loading ? 'Aguarde...' : 'Entrar'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading ? null : forgotPassword,
                    child: const Text('Esqueci minha senha'),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ou'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : google,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Entrar com Google'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : apple,
                      icon: const Icon(Icons.apple),
                      label: const Text('Entrar com Apple'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading ? null : createAccount,
                    child: const Text('Criar nova conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final companyName = TextEditingController();
  final companyDocument = TextEditingController();
  final companyAddress = TextEditingController();
  final companyPhone = TextEditingController();
  final companyEmail = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    companyName.dispose();
    companyDocument.dispose();
    companyAddress.dispose();
    companyPhone.dispose();
    companyEmail.dispose();
    super.dispose();
  }

  Future<void> create() async {
    if (email.text.trim().isEmpty || password.text.isEmpty || companyName.text.trim().isEmpty) {
      setState(() => error = 'Informe e-mail, senha e nome da empresa.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AuthRepository().signUp(
        email.text.trim(),
        password.text,
        companyName: companyName.text.trim(),
        companyDocument: companyDocument.text,
        companyAddress: companyAddress.text,
        companyPhone: companyPhone.text,
        companyEmail: companyEmail.text,
      );
      if (!mounted) return;
      if (result.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada. Verifique seu e-mail para concluir o acesso.')),
        );
      }
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Não foi possível criar a conta.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar nova conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Acesso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
                  const SizedBox(height: 22),
                  const Text('Dados básicos da empresa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(controller: companyName, decoration: const InputDecoration(labelText: 'Nome da empresa', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: companyDocument, decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: companyAddress, decoration: const InputDecoration(labelText: 'Endereço', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: companyPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: companyEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail da empresa', border: OutlineInputBorder())),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : create,
                      child: Text(loading ? 'Criando...' : 'Criar conta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  final String message;

  const AccessDeniedPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 56),
                      const SizedBox(height: 16),
                      const Text('Acesso negado', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => AuthRepository().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
