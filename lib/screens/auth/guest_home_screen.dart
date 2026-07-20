import 'package:flutter/material.dart';

/// Accueil Visiteur — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/guest_home_screen.dart
/// Visiteur peut naviguer librement — bottom sheet à panier/commande
class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  /// Affiche bottom sheet d'inscription quand visiteur tente d'acheter
  static void showInscriptionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Créez un compte pour commander',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D2B5E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inscrivez-vous pour passer commande et suivre vos livraisons.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            // Bouton S'inscrire
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2B5E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // TODO : navigate to role selection → auth inscription
                  Navigator.pushNamed(context, '/role-selection');
                },
                child: const Text('S\'inscrire',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Se connecter
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0D2B5E)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/role-selection');
                },
                child: const Text('Se connecter',
                    style: TextStyle(color: Color(0xFF0D2B5E), fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            // Bouton Continuer à naviguer
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Continuer à naviguer',
                style: TextStyle(color: Color(0xFF666666)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B5E),
        title: const Text(
          'CommercHaiti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/role-selection'),
            child: const Text(
              'Se connecter',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_outlined,
                size: 80, color: Color(0xFF0D2B5E)),
            const SizedBox(height: 16),
            const Text(
              'Bienvenue sur CommercHaiti',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D2B5E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Parcourez les boutiques librement.',
              style: TextStyle(color: Color(0xFF666666)),
            ),
            const SizedBox(height: 32),
            // TODO : afficher liste boutiques (ShopProvider)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2B5E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              onPressed: () {
                // TODO : navigate to boutiques screen
              },
              child: const Text('Voir les boutiques',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}