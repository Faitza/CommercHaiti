import 'package:flutter/material.dart';

/// Écran 3 — Accueil Client
/// Message de bienvenue personnalisé + recherche + produits populaires
/// + boutiques ouvertes. Le [userName] doit venir de Firestore
/// users/{uid}.nom une fois Firebase connecté.
class ClientHomeScreen extends StatelessWidget {
  final String userName;

  const ClientHomeScreen({super.key, this.userName = 'Marie'});

  static const Color navy = Color(0xFF0D2B5E);
  static const Color red = Color(0xFFE63946);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Topbar : logo + recherche + bienvenue ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              color: navy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: red,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🛒', style: TextStyle(fontSize: 15)),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CommercHaiti',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '📍 Les Cayes',
                            style: TextStyle(fontSize: 9, color: Colors.white54),
                          ),
                        ],
                      ),
                      const Spacer(),
                      _IconButton(
                        icon: Icons.shopping_cart_outlined,
                        badge: '2',
                        onTap: () => Navigator.pushNamed(context, '/cart'),
                      ),
                      const SizedBox(width: 7),
                      _IconButton(
                        icon: Icons.menu,
                        onTap: () => _openMenu(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Message de bienvenue — à la place de la recherche
                  Text(
                    '👋 Bonjour $userName,',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Que voulez-vous aujourd\'hui ?',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const SizedBox(height: 10),

                  // Barre de recherche — sous le message
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, size: 16, color: Colors.white54),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Rechercher produit ou boutique…',
                            style: TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                        ),
                        Icon(Icons.tune, size: 16, color: Colors.white60),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps de page ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(13),
                children: [
                  _PromoBanner(),
                  const SizedBox(height: 14),

                  _SectionTitle(
                    title: '🔥 Produits les plus demandés',
                    actionLabel: 'Voir tout',
                  ),
                  const SizedBox(height: 8),
                  // TODO: remplacer par un StreamBuilder sur
                  // Firestore products orderBy totalCommandes desc limit(10)
                  const SizedBox(
                    height: 170,
                    child: Center(child: Text('Grille produits ici')),
                  ),

                  const SizedBox(height: 16),
                  _SectionTitle(
                    title: '🏪 Boutiques ouvertes',
                    actionLabel: 'Voir tout',
                  ),
                  const SizedBox(height: 8),
                  // TODO: remplacer par un StreamBuilder sur
                  // Firestore shops where isOpen == true
                  const SizedBox(
                    height: 80,
                    child: Center(child: Text('Liste boutiques ici')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // ── Bottom nav : 3 boutons ──
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        height: 60,
        backgroundColor: Colors.white,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: navy),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: navy),
            label: 'Panier',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: navy),
            label: 'Commandes',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 1) Navigator.pushNamed(context, '/cart');
          if (index == 2) Navigator.pushNamed(context, '/orders');
        },
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(icon: Icons.storefront, label: 'Boutiques'),
            _MenuItem(icon: Icons.category_outlined, label: 'Catégories'),
            _MenuItem(icon: Icons.favorite_border, label: 'Favoris'),
            _MenuItem(icon: Icons.person_outline, label: 'Mon profil'),
            _MenuItem(icon: Icons.dark_mode_outlined, label: 'Mode sombre'),
            _MenuItem(icon: Icons.settings_outlined, label: 'Paramètres'),
            const Divider(),
            _MenuItem(
              icon: Icons.logout,
              label: 'Déconnexion',
              color: Colors.red,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════ Widgets réutilisables ═══════════════════════

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _IconButton({required this.icon, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: 18, color: Colors.white)),
            if (badge != null)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE63946),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE63946), Color(0xFFC0202C)],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: const [
          Text('🏷️', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 Promo du jour !',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '-20% sur tous les fruits — Marché Frais Lakay',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;

  const _SectionTitle({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1F36),
          ),
        ),
        Text(
          actionLabel,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D2B5E),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuItem({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0D2B5E)),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.black87,
        ),
      ),
      onTap: () => Navigator.pop(context),
    );
  }
}
