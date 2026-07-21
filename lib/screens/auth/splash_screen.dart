import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

/// Splash Screen — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : a
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _redirect();
  }

  Future<void> _redirect() async {
    // Attendre 2.5 secondes
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final onboardingVu = prefs.getBool('onboarding_done') ?? false;

    if (!mounted) return;

    // Utilisateur déjà connecté → Dashboard ou Accueil
    if (auth.isLoggedIn) {
      if (auth.isSeller) {
        context.go('/vendor/dashboard');
      } else {
        context.go('/client/home');
      }
      return;
    }

    // Première ouverture → Onboarding
    if (!onboardingVu) {
      context.go('/onboarding');
      return;
    }

    // Ouvertures suivantes → Choix du rôle
    context.go('/role-selection');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2B5E),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text('CH', style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold,
                      color: Color(0xFF0D2B5E),
                    )),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('CommercHaiti', style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 1.2,
                )),
                const SizedBox(height: 8),
                const Text('Marketplace locale des Cayes',
                    style: TextStyle(fontSize: 14,
                        color: Color(0xFFB5D4F4))),
                const SizedBox(height: 60),
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}