import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

/// Écran Connexion / Inscription — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/auth_screen.dart
class AuthScreen extends StatefulWidget {
  final String role; // 'seller' ou 'customer'
  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Champs communs
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _nomCtrl         = TextEditingController();
  final _telephoneCtrl   = TextEditingController();

  // Champs client
  final _adresseCtrl     = TextEditingController();

  // Champs vendeur
  final _nomBoutiqueCtrl  = TextEditingController();
  final _descriptionCtrl  = TextEditingController();
  String _shopCodePreview = '';

  bool _obscurePassword = true;

  bool get isVendeur => widget.role == 'seller';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nomBoutiqueCtrl.addListener(_updateShopCode);
  }

  void _updateShopCode() {
    if (_nomBoutiqueCtrl.text.isNotEmpty) {
      final code = context
          .read<AuthProvider>()
          .generateShopCode(_nomBoutiqueCtrl.text);
      setState(() => _shopCodePreview = code);
    }
  }

  // ── Validations ──
  String? _validateNom(String? v) {
    if (v == null || v.isEmpty) return 'Nom requis';
    if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(v))
      return 'Lettres uniquement';
    if (v.length < 2) return 'Nom trop court';
    return null;
  }

  String? _validateTelephone(String? v) {
    if (v == null || v.isEmpty) return 'Téléphone requis';
    if (!RegExp(r'^[\+0-9\s]+$').hasMatch(v))
      return 'Chiffres uniquement';
    if (v.replaceAll(RegExp(r'[^\d]'), '').length < 8)
      return 'Numéro trop court';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email requis';
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$').hasMatch(v))
      return 'Email invalide';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe requis';
    if (v.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  // ── Connexion ──
  Future<void> _connexion() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signIn(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (!mounted) return;
    if (success) {
      if (auth.isSeller) {
        context.go('/vendor/dashboard');
      } else {
        context.go('/client/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Erreur connexion'),
        backgroundColor: const Color(0xFFE63946),
      ));
    }
  }

  // ── Inscription ──
  Future<void> _inscription() async {
    final auth = context.read<AuthProvider>();
    bool success = false;

    if (isVendeur) {
      success = await auth.signUpVendeur(
        nom:          _nomCtrl.text.trim(),
        telephone:    _telephoneCtrl.text.trim(),
        email:        _emailCtrl.text.trim(),
        password:     _passwordCtrl.text,
        nomBoutique:  _nomBoutiqueCtrl.text.trim(),
        description:  _descriptionCtrl.text.trim(),
      );
    } else {
      success = await auth.signUpClient(
        nom:       _nomCtrl.text.trim(),
        telephone: _telephoneCtrl.text.trim(),
        adresse:   _adresseCtrl.text.trim(),
        email:     _emailCtrl.text.trim(),
        password:  _passwordCtrl.text,
      );
    }

    if (!mounted) return;
    if (success) {
      if (isVendeur) {
        context.go('/create-shop',
            extra: {'shopCode': _shopCodePreview});
      } else {
        context.go('/client/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? 'Erreur inscription'),
        backgroundColor: const Color(0xFFE63946),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        foregroundColor: Colors.white,
        title: Text(isVendeur ? 'Espace Vendeur' : 'Espace Client'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE63946),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Connexion'),
            Tab(text: 'Inscription'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnexion(auth),
          _buildInscription(auth),
        ],
      ),
    );
  }

  Widget _buildConnexion(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _label('Email *'),
          _field(_emailCtrl, 'exemple@email.com',
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _label('Mot de passe *'),
          _passwordField(),
          const SizedBox(height: 32),
          _boutonPrincipal('Se connecter', _connexion, auth.isLoading),
          const SizedBox(height: 16),
          _boutonGoogle(auth),
          if (!isVendeur) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.go('/guest'),
                child: const Text('Parcourir sans s\'inscrire',
                    style: TextStyle(color: Color(0xFF666666),
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInscription(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _label('Nom complet *'),
          _field(_nomCtrl, 'Marie Joseph', validator: _validateNom),
          const SizedBox(height: 16),
          _label('Téléphone *'),
          _field(_telephoneCtrl, '+509 XXXX XXXX',
              validator: _validateTelephone,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _label('Email *'),
          _field(_emailCtrl, 'exemple@email.com',
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _label('Mot de passe *'),
          _passwordField(),

          // Champs client
          if (!isVendeur) ...[
            const SizedBox(height: 16),
            _label('Adresse de livraison *'),
            _field(_adresseCtrl, 'Cayes, Rue...',
                validator: (v) => v == null || v.length < 5
                    ? 'Adresse trop courte' : null),
          ],

          // Champs vendeur
          if (isVendeur) ...[
            const SizedBox(height: 16),
            _label('Nom de la boutique *'),
            _field(_nomBoutiqueCtrl, 'Marché Frais Lakay',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nom requis';
                  if (v.length < 3) return 'Minimum 3 caractères';
                  if (v.length > 50) return 'Maximum 50 caractères';
                  return null;
                }),
            if (_shopCodePreview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.tag, size: 16, color: Color(0xFF0D2B5E)),
                  const SizedBox(width: 8),
                  Text('Code boutique : $_shopCodePreview',
                      style: const TextStyle(color: Color(0xFF0D2B5E),
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            _label('Description de la boutique *'),
            _field(_descriptionCtrl,
                'Décrivez votre boutique en quelques mots...',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Description requise';
                  if (v.length < 10) return 'Minimum 10 caractères';
                  if (v.length > 200) return 'Maximum 200 caractères';
                  return null;
                },
                maxLines: 3),
          ],

          const SizedBox(height: 32),
          _boutonPrincipal('S\'inscrire', _inscription, auth.isLoading),
          const SizedBox(height: 16),
          _boutonGoogle(auth),
        ],
      ),
    );
  }

  // ── Widgets helpers ──
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600, color: Color(0xFF1A1F36))),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {String? Function(String?)? validator,
      TextInputType? keyboardType,
      int maxLines = 1}) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE63946))),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordCtrl,
        obscureText: _obscurePassword,
        validator: _validatePassword,
        decoration: InputDecoration(
          hintText: 'Minimum 6 caractères',
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword
                ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      );

  Widget _boutonPrincipal(String label, VoidCallback onPressed,
      bool isLoading) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D2B5E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _boutonGoogle(AuthProvider auth) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFCCCCCC)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Text('G', style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
          label: const Text('Continuer avec Google',
              style: TextStyle(color: Color(0xFF1A1F36))),
          onPressed: auth.isLoading ? null : () => auth.signInWithGoogle(),
        ),
      );

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _adresseCtrl.dispose();
    _nomBoutiqueCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }
}