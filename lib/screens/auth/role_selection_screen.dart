import 'package:flutter/material.dart';

/// Écran 1 — Choix du rôle (Vendeur / Client)
/// Première page affichée au lancement de l'application.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 'vendor' ou 'client' — null tant que rien n'est sélectionné
  String? _selectedRole;

  static const Color navy = Color(0xFF0D2B5E);
  static const Color red = Color(0xFFE63946);
  static const Color lightBlue = Color(0xFFEEF3FB);
  static const Color lightRed = Color(0xFFFDEAEA);

  void _continue() {
    if (_selectedRole == null) return;

    if (_selectedRole == 'vendor') {
      Navigator.pushNamed(context, '/auth-vendor');
    } else {
      Navigator.pushNamed(context, '/auth-client');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête bleu marine ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              decoration: const BoxDecoration(color: navy),
              child: const Column(
                children: [
                  Text('👋', style: TextStyle(fontSize: 36)),
                  SizedBox(height: 12),
                  Text(
                    'Bienvenue sur\nCommercHaiti !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Comment souhaitez-vous utiliser l\'application ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps : cartes de sélection ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RoleCard(
                      icon: '🏪',
                      iconBg: lightBlue,
                      title: 'Je suis Vendeur',
                      description:
                          'Je veux créer ma boutique et vendre mes produits en ligne',
                      selected: _selectedRole == 'vendor',
                      onTap: () => setState(() => _selectedRole = 'vendor'),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: '🛒',
                      iconBg: lightRed,
                      title: 'Je suis Client',
                      description:
                          'Je veux parcourir les boutiques et commander des produits',
                      selected: _selectedRole == 'client',
                      onTap: () => setState(() => _selectedRole = 'client'),
                    ),
                    const SizedBox(height: 20),

                    // Avertissement
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                          left: BorderSide(color: Color(0xFFF5A623), width: 3),
                        ),
                      ),
                      child: const Text(
                        '⚠️ Ce choix est définitif. Un vendeur ne peut pas '
                        'passer commande et vice-versa. Créez deux comptes '
                        'si nécessaire.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7A4F00),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton Continuer
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _selectedRole == null ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: red,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continuer →',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte de sélection de rôle réutilisable
class _RoleCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  static const Color navy = Color(0xFF0D2B5E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF3FB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? navy : const Color(0xFFE0E3EA),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? navy : Colors.transparent,
                border: Border.all(
                  color: selected ? navy : const Color(0xFFE0E3EA),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
