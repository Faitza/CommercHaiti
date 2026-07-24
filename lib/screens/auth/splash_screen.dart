import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

/// Splash Screen — Faitza COLAS
/// Path : lib/screens/auth/splash_screen.dart
// Premier écran affiché au lancement de l'application (route initiale
// '/splash' dans app_router.dart). Affiche le logo avec une animation
// d'apparition, puis redirige automatiquement l'utilisateur vers le bon
// écran selon son état (déjà connecté, onboarding déjà vu, etc.).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Contrôleur pilotant les deux animations (fondu + zoom) du logo.
  late AnimationController _controller;
  // Animation de fondu (opacité 0 → 1).
  late Animation<double> _fadeAnimation;
  // Animation de zoom (échelle 0.8 → 1.0).
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Durée totale de l'animation d'entrée : 1.2 secondes.
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    // Fondu progressif avec courbe "easeIn" (démarre lentement).
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    // Zoom léger avec courbe "easeOut" (ralentit en fin d'animation).
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    // Démarre l'animation dès l'affichage de l'écran.
    _controller.forward();
    // Lance en parallèle la logique de redirection (ne bloque pas
    // l'animation visuelle).
    _redirect();
  }

  // Détermine vers quel écran rediriger l'utilisateur après un court
  // délai (le temps que le logo s'affiche). Logique :
  //  1. Si l'utilisateur est déjà connecté (auth.isLoggedIn) → direction
  //     directe vers son tableau de bord (vendeur ou client).
  //  2. Sinon, si l'onboarding (les 3 slides d'introduction) n'a jamais
  //     été vu → on l'affiche.
  //  3. Sinon → écran de choix de rôle (Client/Vendeur).
  Future<void> _redirect() async {
    // Petit délai artificiel pour laisser le temps à l'animation/logo de
    // s'afficher correctement avant de naviguer.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    // Lecture de la préférence locale indiquant si l'onboarding a déjà
    // été terminé par l'utilisateur (stockée via shared_preferences).
    final prefs = await SharedPreferences.getInstance();
    final onboardingVu = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    // On attend la fin du frame courant avant de naviguer, pour éviter
    // de déclencher une navigation pendant une phase de construction du
    // widget (bonne pratique avec GoRouter/Navigator).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (auth.isLoggedIn) {
        // Utilisateur déjà connecté : direction directe selon son rôle.
        context.go(auth.isSeller ? '/vendor/dashboard' : '/client/home');
        return;
      }
      // Utilisateur non connecté : onboarding si pas encore vu, sinon
      // choix du rôle.
      context.go(!onboardingVu ? '/onboarding' : '/role-selection');
    });
  }

  @override
  void dispose() {
    // Libère les ressources de l'AnimationController.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B5E),
      body: Center(
        // Combine les deux animations (fondu + zoom) sur le contenu du logo.
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo — jan demo a montre l
                // Logo de l'application. `errorBuilder` fournit un
                // remplacement (icône panier dans un carré rouge) si le
                // fichier image est introuvable, pour éviter un écran
                // cassé.
                Image.asset(
                  'assets/images/logo.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE63946),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.shopping_cart,
                        color: Colors.white, size: 60),
                  ),
                ),
                const SizedBox(height: 20),
                // CommercHaiti
                // Nom de l'application avec deux couleurs différentes
                // ("Commerc" en blanc, "Haiti" en rouge) via RichText/TextSpan.
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5),
                    children: [
                      TextSpan(text: 'Commerc',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Haiti',
                          style: TextStyle(color: Color(0xFFE63946))),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Sous-titre / slogan.
                const Text('MARKETPLACE LOCALE',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                        letterSpacing: 3)),
                const SizedBox(height: 60),
                // Localisation de l'application.
                const Text('Les Cayes - Haïti',
                    style: TextStyle(fontSize: 12, color: Colors.white30)),
                const SizedBox(height: 16),
                // Trois petits points décoratifs en bas (indicateur visuel
                // de chargement statique, le premier point en rouge attire
                // l'œil comme un indicateur de progression).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFFE63946)
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
