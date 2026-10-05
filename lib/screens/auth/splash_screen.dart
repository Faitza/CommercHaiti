import 'dart:math';
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
    with TickerProviderStateMixin {
  // Contrôleur pilotant les deux animations (fondu + zoom) du logo.
  late AnimationController _controller;
  // Animation de fondu (opacité 0 → 1).
  late Animation<double> _fadeAnimation;
  // Animation de zoom (échelle 0.8 → 1.0).
  late Animation<double> _scaleAnimation;
  // Contrôleur SÉPARÉ (TickerProviderStateMixin, plutôt que
  // SingleTickerProviderStateMixin, car il faut désormais DEUX
  // AnimationController actifs en même temps) qui boucle en continu pour
  // faire "vivre" les 3 points de chargement en bas de l'écran, comme un
  // indicateur d'app en train de démarrer (effet façon Facebook).
  late AnimationController _dotsController;

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

    // `..repeat()` : boucle indéfiniment (contrairement à `_controller`
    // qui ne joue qu'une fois). Sa valeur (0 → 1 en 1,2 s, en boucle) sert
    // de base de temps commune aux 3 points, chacun décalé dans le temps
    // (voir `_dot()` plus bas) pour créer un effet de vague.
    _dotsController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat();

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
    // Le logo et les points restent affichés AU MOINS 5 secondes (demande
    // de Faitza). La lecture des préférences se fait pendant ce temps,
    // donc la durée totale reste 5 s et pas 5 s + lecture.
    final resultats = await Future.wait([
      Future.delayed(const Duration(seconds: 5)),
      // Lecture de la préférence locale indiquant si l'onboarding a déjà
      // été terminé par l'utilisateur (stockée via shared_preferences).
      SharedPreferences.getInstance(),
    ]);
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final prefs = resultats[1] as SharedPreferences;
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
    // Libère les ressources des deux AnimationController.
    _controller.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  // Un point de l'indicateur de chargement. Les 3 points sautent l'un
  // après l'autre (décalage d'un tiers de cycle chacun), comme une petite
  // vague : chaque point monte de 8 px, grossit et devient plein, puis
  // redescend et pâlit avant que le suivant ne prenne le relais.
  // (Avant : points de 8 px qui ne variaient que de taille, à peine
  // visibles, et l'écran ne restait que 0,7 s.)
  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        // Phase 0..1 propre à ce point, décalée d'un tiers par point.
        final phase = (_dotsController.value - index / 3) % 1.0;
        // Impulsion : le point est « actif » pendant la première moitié
        // de sa phase (sin de 0 à π), au repos pendant la seconde.
        final pulse = phase < 0.5 ? sin(phase * 2 * pi) : 0.0;
        final couleur =
            index == 0 ? const Color(0xFFE63946) : Colors.white;
        return Transform.translate(
          offset: Offset(0, -8 * pulse),
          child: Transform.scale(
            scale: 0.8 + 0.4 * pulse,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.35 + 0.65 * pulse),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
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
                // Trois points de chargement ANIMÉS (effet de vague en
                // boucle, façon indicateur de démarrage Facebook) — voir
                // `_dot()` plus bas.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _dot(i),
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
