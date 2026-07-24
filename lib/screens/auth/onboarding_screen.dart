import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding Screen — Faitza COLAS
/// Path : lib/screens/auth/onboarding_screen.dart
// Écran d'introduction affiché une seule fois (au tout premier lancement,
// avant que l'utilisateur n'ait de compte). Présente 3 slides défilables
// expliquant le principe de l'application. Une fois terminé, on mémorise
// ce fait dans SharedPreferences pour ne plus jamais réafficher cet écran
// (voir splash_screen.dart qui vérifie ce drapeau).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Contrôleur du PageView permettant de naviguer entre les slides
  // (défilement manuel ou via le bouton "Suivant").
  final PageController _pageController = PageController();
  // Index de la slide actuellement affichée (utilisé pour les points
  // indicateurs et pour savoir si le bouton "Passer" doit être visible).
  int _currentPage = 0;

  // Contenu des 3 slides d'introduction, définies une fois pour toutes.
  final List<_Slide> _slides = [
    _Slide(
      icon: Icons.storefront_rounded,
      titre: 'Bienvenue sur CommercHaiti !',
      description: 'Découvrez les meilleures boutiques locales des Cayes et commandez en quelques clics.',
      bouton: 'Suivant',
      showPasser: false, // Première slide : pas de bouton "Passer" (l'utilisateur vient d'arriver).
    ),
    _Slide(
      icon: Icons.location_city_rounded,
      titre: 'Des boutiques près de vous',
      description: 'Alimentation, mode, électronique… Parcourez des dizaines de boutiques locales et comparez les prix facilement.',
      bouton: 'Suivant',
      showPasser: true,
    ),
    _Slide(
      icon: Icons.local_shipping_rounded,
      titre: 'Livraison rapide chez vous',
      description: 'Passez vos commandes, suivez votre livraison en temps réel et payez à la réception. Simple, rapide et sécurisé.',
      bouton: 'Commencer',
      showPasser: false, // Dernière slide : le bouton "Commencer" fait déjà office de sortie.
    ),
  ];

  // Marque l'onboarding comme terminé (persisté localement) puis redirige
  // vers l'écran de choix de rôle. Appelé soit via "Passer", soit via le
  // bouton "Commencer" de la dernière slide.
  Future<void> _terminer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go('/role-selection');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Liste défilable horizontalement des 3 slides.
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildSlide(_slides[i]),
          ),
          // Bouton Passer
          // Affiché uniquement sur les slides qui le permettent
          // (showPasser == true), positionné en haut à droite, au-dessus
          // du PageView grâce au Stack.
          if (_slides[_currentPage].showPasser)
            Positioned(
              top: 44, right: 16,
              child: TextButton(
                onPressed: _terminer,
                child: const Text('Passer',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }

  // Construit visuellement une slide : illustration en haut, puis texte +
  // indicateurs de pagination + bouton d'action en bas.
  Widget _buildSlide(_Slide slide) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B5E), Color(0xFF1a4a9e), Color(0xFF0D2B5E)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Illustration — mwatye siperyè
            // Partie supérieure : illustration spécifique pour la
            // première slide (silhouette + téléphone + sac de courses),
            // sinon une simple icône encerclée pour les autres slides.
            Expanded(
              flex: 5,
              child: Center(
                child: slide.icon == Icons.storefront_rounded
                    ? _IllustrationClientPhone()
                    : Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: Icon(slide.icon, size: 78, color: Colors.white),
                      ),
              ),
            ),

            // Kontni anba
            // Partie inférieure : titre, description, indicateurs de
            // pagination, bouton d'action et lien "déjà un compte".
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tit
                    Text(slide.titre,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25)),
                    const SizedBox(height: 10),
                    // Deskripsyon
                    Text(slide.description,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.5)),
                    // Pousse le reste du contenu (points + bouton) vers le
                    // bas, quel que soit l'espace occupé par le texte.
                    const Spacer(),
                    // Pwen indikatè
                    // Points de pagination : le point correspondant à la
                    // slide actuelle est plus large et coloré en rouge.
                    Row(
                      children: List.generate(_slides.length, (i) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 6),
                          width: _currentPage == i ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? const Color(0xFFE63946)
                                : Colors.white30,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
                    ),
                    const SizedBox(height: 14),
                    // Bouton
                    // Bouton "Suivant"/"Commencer" : avance à la slide
                    // suivante avec une animation si ce n'est pas la
                    // dernière, sinon termine l'onboarding.
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE63946),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
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
                        child: Text('${slide.bouton} →',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Deja yon kont
                    // Lien pour les utilisateurs ayant déjà un compte :
                    // saute directement l'onboarding sans le marquer comme
                    // terminé (note : ici on ne persiste pas le drapeau,
                    // contrairement à `_terminer`).
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/role-selection'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                            children: [
                              TextSpan(text: 'Déjà un compte ? '),
                              TextSpan(
                                text: 'Se connecter',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline),
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
      ),
    );
  }
}

/// Illustration slide 1 — cliente qui vient de faire du shopping, téléphone
/// en main (approximation composée en icônes — pas d'asset image dispo).
// Widget purement décoratif : combine plusieurs icônes superposées (Stack)
// pour simuler une illustration sans avoir besoin d'un fichier image dédié.
class _IllustrationClientPhone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180, height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercle de fond semi-transparent.
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
          // Silhouette cliente
          const Icon(Icons.person, size: 92, color: Colors.white),
          // Téléphone dans la main
          // Petit badge orange positionné en bas à droite de la silhouette.
          Positioned(
            bottom: 46, right: 44,
            child: Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFFF5A623),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smartphone,
                  size: 18, color: Colors.white),
            ),
          ),
          // Sac de shopping
          // Petit badge rouge positionné en bas à gauche de la silhouette.
          Positioned(
            bottom: 30, left: 36,
            child: Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFE63946),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag,
                  size: 19, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Modèle de données simple représentant le contenu d'une slide
// d'onboarding (icône, titre, description, texte du bouton, et si le
// bouton "Passer" doit être affiché).
class _Slide {
  final IconData icon;
  final String titre;
  final String description;
  final String bouton;
  final bool showPasser;
  const _Slide({
    required this.icon,
    required this.titre,
    required this.description,
    required this.bouton,
    required this.showPasser,
  });
}
