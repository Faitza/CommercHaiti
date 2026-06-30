import 'package:flutter/material.dart';

/// Écran 2 — Connexion / Inscription
/// Un seul widget réutilisé pour Client et Vendeur, avec [isVendor]
/// qui détermine les champs affichés et les options disponibles.
class AuthScreen extends StatefulWidget {
  final bool isVendor;

  const AuthScreen({super.key, required this.isVendor});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginTab = true; // true = Connexion, false = Inscription

  static const Color navy = Color(0xFF0D2B5E);
  static const Color darkNavy = Color(0xFF061A3A);
  static const Color red = Color(0xFFE63946);

  // Contrôleurs - Connexion
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Contrôleurs - Inscription (communs)
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();

  // Contrôleurs - Inscription Client uniquement
  final _addressCtrl = TextEditingController();

  // Contrôleurs - Inscription Vendeur uniquement
  final _shopNameCtrl = TextEditingController();
  final _shopDescCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _addressCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopDescCtrl.dispose();
    super.dispose();
  }

  /// Génère un code boutique au format MFL-2026-4892
  String _generateShopCode(String shopName) {
    final initials = shopName
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(3)
        .join();
    final year = DateTime.now().year;
    final random = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000));
    return '$initials-$year-$random';
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = widget.isVendor ? darkNavy : navy;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              color: headerColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: widget.isVendor
                              ? const Color(0xFFEEF3FB)
                              : const Color(0xFFFDEAEA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.isVendor ? '🏪' : '🛒',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isVendor ? 'Espace Vendeur' : 'Espace Client',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'CommercHaiti',
                            style: TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        _TabButton(
                          label: 'Connexion',
                          active: _isLoginTab,
                          onTap: () => setState(() => _isLoginTab = true),
                        ),
                        _TabButton(
                          label: 'Inscription',
                          active: !_isLoginTab,
                          onTap: () => setState(() => _isLoginTab = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _isLoginTab ? _buildLoginForm() : _buildRegisterForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Connexion ─────────────────────────
  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('Email'),
        _TextField(controller: _emailCtrl, hint: 'exemple@gmail.com'),
        const SizedBox(height: 10),
        _FieldLabel('Mot de passe'),
        _TextField(controller: _passwordCtrl, obscure: true, hint: '••••••••'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Mot de passe oublié ?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isVendor ? darkNavy : navy,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: '🔐 Se connecter',
          color: widget.isVendor ? navy : red,
          onTap: () {
            // TODO: appeler AuthService.signIn(email, password)
            // puis rediriger selon le rôle stocké dans Firestore
          },
        ),
        const SizedBox(height: 14),
        _OrDivider(),
        const SizedBox(height: 14),
        _GoogleButton(label: 'Continuer avec Google'),

        if (!widget.isVendor) ...[
          const SizedBox(height: 14),
          _OrDivider(),
          const SizedBox(height: 14),
          _GhostButton(
            label: '👀 Parcourir sans s\'inscrire',
            color: navy,
            onTap: () {
              // TODO: activer le mode visiteur (sans Firebase Auth)
              Navigator.pushReplacementNamed(context, '/home-guest');
            },
          ),
        ],
      ],
    );
  }

  // ───────────────────────── Inscription ─────────────────────────
  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel('Nom complet'),
        _TextField(controller: _nameCtrl, hint: 'Jean-Pierre Louis'),
        const SizedBox(height: 10),
        _FieldLabel('Téléphone'),
        _TextField(controller: _phoneCtrl, hint: '+509 3712 4856'),
        const SizedBox(height: 10),

        if (!widget.isVendor) ...[
          _FieldLabel('Adresse principale'),
          _TextField(controller: _addressCtrl, hint: 'Rue Borno, Les Cayes'),
          const SizedBox(height: 10),
        ],

        _FieldLabel('Email'),
        _TextField(controller: _regEmailCtrl, hint: 'exemple@gmail.com'),
        const SizedBox(height: 10),
        _FieldLabel('Mot de passe'),
        _TextField(controller: _regPasswordCtrl, obscure: true, hint: '••••••••'),

        if (widget.isVendor) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _FieldLabel('🏪 Nom de la boutique'),
          _TextField(controller: _shopNameCtrl, hint: 'Marché Frais Lakay'),
          const SizedBox(height: 10),
          _FieldLabel('📝 Description'),
          _TextField(
            controller: _shopDescCtrl,
            hint: 'Fruits frais, légumes, épices…',
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          // Aperçu du code boutique généré
          AnimatedBuilder(
            animation: _shopNameCtrl,
            builder: (context, _) {
              final code = _shopNameCtrl.text.trim().isEmpty
                  ? '———-————-————'
                  : _generateShopCode(_shopNameCtrl.text);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: navy, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎫 CODE BOUTIQUE GÉNÉRÉ AUTOMATIQUEMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: navy,
                        letterSpacing: .4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: navy,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Conservez ce code — il identifie votre boutique',
                      style: TextStyle(fontSize: 10, color: Colors.black45),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 18),
        _PrimaryButton(
          label: widget.isVendor ? '✅ Créer ma boutique' : '✅ Créer mon compte',
          color: widget.isVendor ? navy : red,
          onTap: () {
            // TODO Vendeur :
            // 1. AuthService.signUp(email, password)
            // 2. shopCode = _generateShopCode(_shopNameCtrl.text)
            // 3. Créer users/{uid} avec role: 'seller', shopCode
            // 4. Créer shops/{sid} avec proprietaireId, nom, description, shopCode
            // 5. Rediriger vers Dashboard vendeur
            //
            // TODO Client :
            // 1. AuthService.signUp(email, password)
            // 2. Créer users/{uid} avec role: 'customer', adresse, telephone
            // 3. Rediriger vers Accueil client
          },
        ),
        const SizedBox(height: 14),
        _OrDivider(),
        const SizedBox(height: 14),
        _GoogleButton(
          label: widget.isVendor
              ? 'S\'inscrire avec Google'
              : 'S\'inscrire avec Google',
        ),

        if (!widget.isVendor) ...[
          const SizedBox(height: 14),
          _OrDivider(),
          const SizedBox(height: 14),
          _GhostButton(
            label: '👀 Parcourir sans s\'inscrire',
            color: navy,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home-guest');
            },
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════ Widgets réutilisables ═══════════════════════

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF0D2B5E) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF666666),
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFE8EAF0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFE8EAF0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF0D2B5E), width: 1.5),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final String label;
  const _GoogleButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: () {
          // TODO: AuthService.signInWithGoogle()
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE0E3EA), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌐', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: Color(0xFFE0E3EA))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('ou', style: TextStyle(fontSize: 10, color: Colors.black38)),
        ),
        Expanded(child: Divider(color: Color(0xFFE0E3EA))),
      ],
    );
  }
}
