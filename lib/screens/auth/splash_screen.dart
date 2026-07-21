import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

/// Splash Screen — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/splash_screen.dart
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
    // Etap 1 — Tann 2.5 segonn
    await Future.delayed(const Duration(milliseconds: 2500));

    // Etap 2 — Verifye widget toujou la
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final onboardingVu = prefs.getBool('onboarding_done') ?? false;

    // Etap 3 — Verifye ankò apre async
    if (!mounted) return;

    // Etap 4 — Navige apre paj la fin afiche nèt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (auth.isLoggedIn) {
        context.go(auth.isSeller
            ? '/vendor/dashboard'
            : '/client/home');
        return;
      }

      context.go(!onboardingVu ? '/onboarding' : '/role-selection');
    });
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
                Image.asset(
                  'assets/images/logo.png',
                  width: 150,
                  height: 150,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text('CH', style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D2B5E),
                      )),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Nom app
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                    children: [
                      TextSpan(text: 'Commerc',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'Haiti',
                          style: TextStyle(color: Color(0xFFE63946))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('MARKETPLACE LOCALE',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 3,
                    )),
                const SizedBox(height: 80),
                // Lokasyon
                const Text('Les Cayes - Haïti',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white38)),
                const SizedBox(height: 16),
                // Indicateurs (3 points)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? const Color(0xFFE63946)
                          : Colors.white24,
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