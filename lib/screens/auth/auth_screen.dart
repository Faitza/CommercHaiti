import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../providers/auth_provider.dart';

/// Écran Connexion / Inscription — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/auth_screen.dart
/// Formulaire différent selon le rôle (Vendeur ou Client)
class AuthScreen extends StatefulWidget {
  final String role; // 'seller' ou 'customer'

  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Champs communs
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _telephoneCtrl = TextEditingController();

  // Champs Client seulement
  final _adresseCtrl = TextEditingController();

  // Champs Vendeur seulement
  final _nomBoutiqueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _shopCodePreview = '';

  bool _isLoading = false;
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
      final mots = _nomBoutiqueCtrl.text.trim().split(' ')
          .where((m) => m.isNotEmpty).toList();
      final initiales = mots.take(3).map((m) => m[0].toUpperCase()).join();
      final annee = DateTime.now().year;
      final random = (DateTime.now().millisecondsSinceEpoch % 9000) + 1000;
      setState(() => _shopCodePreview = '$initiales-$annee-$random');
    }
  }

  // ── Validation ──
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

  String? _validateAdresse(String? v) {
    if (v == null || v.isEmpty) return 'Adresse requise';
    if (v.length < 5) return 'Adresse trop courte';
    return null;
  }

  String? _validateNomBoutique(String? v) {
    if (v == null || v.isEmpty) return 'Nom de boutique requis';
    if (v.length < 3) return 'Minimum 3 caractères';
    if (v.length > 50) return 'Maximum 50 caractères';
    return null;
  }

  String? _validateDescription(String? v) {
    if (v == null || v.isEmpty) return 'Description requise';
    if (v.length < 10) return 'Minimum 10 caractères';
    if (v.length > 200) return 'Maximum 200 caractères';
    return null;
  }

  Future<void> _connexion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO : await context.read<AuthProvider>().signIn(email, password)
    setState(() => _isLoading = false);
  }

  Future<void> _inscription() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO : await context.read<AuthProvider>().signUpClient() ou signUpVendeur()
    setState(() => _isLoading = false);
  }

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

  @override
  Widget build(BuildContext context) {
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
          _buildConnexion(),
          _buildInscription(),
        ],
      ),
    );
  }

  Widget _buildConnexion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
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
            _boutonPrincipal('Se connecter', _connexion),
            const SizedBox(height: 16),
            _boutonGoogle(),
            if (!isVendeur) ...[
              const SizedBox(height: 16),
              _boutonVisiteur(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInscription() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _label('Nom complet *'),
            _field(_nomCtrl, 'Marie Joseph',
                validator: _validateNom),
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

            // Champs Client seulement
            if (!isVendeur) ...[
              const SizedBox(height: 16),
              _label('Adresse de livraison *'),
              _field(_adresseCtrl, 'Cayes, Rue...',
                  validator: _validateAdresse),
            ],

            // Champs Vendeur seulement
            if (isVendeur) ...[
              const SizedBox(height: 16),
              _label('Nom de la boutique *'),
              _field(_nomBoutiqueCtrl, 'Marché Frais Lakay',
                  validator: _validateNomBoutique),
              if (_shopCodePreview.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tag,
                          size: 16, color: Color(0xFF0D2B5E)),
                      const SizedBox(width: 8),
                      Text(
                        'Code boutique : $_shopCodePreview',
                        style: const TextStyle(
                          color: Color(0xFF0D2B5E),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _label('Description de la boutique *'),
              _field(_descriptionCtrl,
                  'Décrivez votre boutique en quelques mots...',
                  validator: _validateDescription,
                  maxLines: 3),
            ],

            const SizedBox(height: 32),
            _boutonPrincipal('S\'inscrire', _inscription),
            const SizedBox(height: 16),
            _boutonGoogle(),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ──

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1F36))),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
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
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE63946)),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
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
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _boutonPrincipal(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading
              ? const Color(0xFFCCCCCC)
              : const Color(0xFF0D2B5E),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _boutonGoogle() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFCCCCCC)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Text('G',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4285F4))),
        label: const Text('Continuer avec Google',
            style: TextStyle(color: Color(0xFF1A1F36))),
        onPressed: () {
          // TODO : context.read<AuthProvider>().signInWithGoogle()
        },
      ),
    );
  }

  Widget _boutonVisiteur() {
    return Center(
      child: TextButton(
        onPressed: () {
          // TODO : Navigate to guest home
          Navigator.pushReplacementNamed(context, '/guest');
        },
        child: const Text(
          'Parcourir sans s\'inscrire',
          style: TextStyle(
              color: Color(0xFF666666),
              decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}