import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_button.dart';

class AuthScreen extends StatefulWidget {
  final String role;

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _registerEmailCtrl = TextEditingController();
  final _registerPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _registerEmailCtrl.dispose();
    _registerPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _loginEmailCtrl.text.trim(),
      password: _loginPasswordCtrl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Erreur de connexion')),
      );
    }
  }

  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text.trim(),
      email: _registerEmailCtrl.text.trim(),
      password: _registerPasswordCtrl.text,
      role: widget.role,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? "Erreur d'inscription")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    final roleLabel = widget.role == 'vendor' ? 'Vendeur' : 'Client';

    return Scaffold(
      appBar: AppBar(
        title: Text('Connexion — $roleLabel'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Se connecter'),
            Tab(text: "S'inscrire"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _loginTab(loading),
          _registerTab(loading),
        ],
      ),
    );
  }

  Widget _loginTab(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Entrez votre email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loginPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimum 6 caractères' : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Se connecter',
              loading: loading,
              onPressed: _login,
            ),
          ],
        ),
      ),
    );
  }

  Widget _registerTab(bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Entrez votre nom' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registerEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Entrez votre email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _registerPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimum 6 caractères' : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(
              label: "Créer mon compte",
              loading: loading,
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}
