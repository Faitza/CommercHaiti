import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

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
      emoji: '🛒',
      titre: 'Bienvenue sur CommercHaiti !',
      description: 'Découvrez et créez vos boutiques locales des Cayes en quelques clics',
    ),
    _OnboardingSlide(
      emoji: '🏪',
      titre: 'Des boutiques près de vous',
      description: 'Parcourez des dizaines de boutiques locales et commandez vos produits facilement',
    ),
    _OnboardingSlide(
      emoji: '📦',
      titre: 'Simple, rapide et local',
      description: 'Achetez ou vendez vos produits, suivez vos livraisons en temps réel',
    ),
  ];

  Future<void> _terminer() async {
    // TODO : marquer onboarding comme vu
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton Passer
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < _slides.length - 1
                  ? TextButton(
                      onPressed: _terminer,
                      child: const Text(
                        'Passer',
                        style: TextStyle(color: Color(0xFF0D2B5E)),
                      ),
                    )
                  : const SizedBox(height: 40),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),

            // Indicateurs points
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? const Color(0xFF0D2B5E)
                        : const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Bouton Suivant / Commencer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B5E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    _currentPage < _slides.length - 1 ? 'Suivant' : 'Commencer',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(slide.emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 32),
          Text(
            slide.titre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D2B5E),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final String emoji;
  final String titre;
  final String description;
  const _OnboardingSlide({
    required this.emoji,
    required this.titre,
    required this.description,
  });
}