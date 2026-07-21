import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding Screen — Faitza COLAS
/// Branch : feature/auth-roles
/// Path : lib/screens/auth/onboarding_screen.dart
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      imagePath: 'assets/images/onboarding1.png',
      titre: 'Bienvenue sur CommercHaiti !',
      description: 'Découvrez les meilleures boutiques locales des Cayes et commandez en quelques clics.',
      bouton: 'Suivant →',
    ),
    _OnboardingSlide(
      imagePath: 'assets/images/onboarding2.png',
      titre: 'Des boutiques près de vous',
      description: 'Alimentation, mode, électronique… Parcourez des dizaines de boutiques locales et comparez les prix facilement.',
      bouton: 'Suivant →',
    ),
    _OnboardingSlide(
      imagePath: 'assets/images/onboarding3.png',
      titre: 'Livraison rapide chez vous',
      description: 'Passez vos commandes, suivez votre livraison en temps réel et payez à la réception. Simple, rapide et sécurisé.',
      bouton: 'Commencer →',
    ),
  ];

  Future<void> _terminer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go('/role-selection');
  }

  void _seConnecter() {
    context.go('/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView fond bleu marine
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildSlide(_slides[i]),
          ),

          // Bouton Passer (anwo adwat)
          if (_currentPage < _slides.length - 1)
            Positioned(
              top: 50, right: 20,
              child: TextButton(
                onPressed: _terminer,
                child: const Text('Passer',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Container(
      color: const Color(0xFF0D2B5E),
      child: Column(
        children: [
          // Image ocipe mwatye ekran anwo
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF0D2B5E),
              child: Image.asset(
                slide.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_outlined,
                  size: 120,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          // Seksyon anba — wouj fen
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0D2B5E),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tit
                  Text(
                    slide.titre,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Deskripsyon
                  Text(
                    slide.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),

                  // Indicateurs + Bouton
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? const Color(0xFFE63946)
                              : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton Suivant / Commencer
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE63946),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _terminer();
                        }
                      },
                      child: Text(
                        slide.bouton,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lyen "Déjà un compte ? Se connecter"
                  Center(
                    child: GestureDetector(
                      onTap: _seConnecter,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 13, color: Colors.white60),
                          children: [
                            TextSpan(text: 'Déjà un compte ? '),
                            TextSpan(
                              text: 'Se connecter',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
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
    );
  }
}

class _OnboardingSlide {
  final String imagePath;
  final String titre;
  final String description;
  final String bouton;

  const _OnboardingSlide({
    required this.imagePath,
    required this.titre,
    required this.description,
    required this.bouton,
  });
}