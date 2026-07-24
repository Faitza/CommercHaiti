import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Role Selection Screen — Faitza COLAS
/// Path : lib/screens/auth/role_selection_screen.dart
// Écran affiché après l'onboarding : l'utilisateur doit choisir s'il
// s'inscrit en tant que Client (acheteur) ou Vendeur (propriétaire de
// boutique). Ce choix conditionne ensuite tout le comportement de
// l'application (routes affichées, formulaire d'inscription, etc.).
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // Rôle actuellement sélectionné par l'utilisateur ('customer' ou 'seller').
  // Reste à null tant qu'aucune carte n'a été cliquée : le bouton
  // "Continuer" est alors désactivé (voir plus bas).
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: Column(
        children: [
          // Header bleu marine — jan demo a
          // En-tête avec dégradé bleu marine, reproduit fidèlement la maquette
          // (jan demo a montre l = "comme le montre la démo" en créole).
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D2B5E), Color(0xFF1a4a9e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.only(
              // On ajoute la hauteur de la zone système (encoche/barre de
              // statut) pour que le contenu ne soit pas caché en haut de
              // l'écran.
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 28,
              left: 20,
              right: 20,
            ),
            width: double.infinity,
            child: Column(
              children: [
                // Ikon bye bye
                // Petite icône "main qui salue" dans un carré semi-transparent.
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.waving_hand,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                // Titre de bienvenue.
                const Text('Bienvenue sur\nCommercHaiti !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2)),
                const SizedBox(height: 8),
                // Sous-titre expliquant l'objectif de cet écran.
                const Text(
                    "Comment souhaitez-vous utiliser l'application ?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),

          // Kat chwa yo
          // Zone scrollable contenant les deux cartes de choix (Client /
          // Vendeur), l'avertissement, et les boutons d'action.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  // Kat Client
                  // Carte de sélection du rôle "Client". `selected` compare
                  // l'état local au rôle représenté par cette carte pour
                  // afficher (ou non) le style "sélectionné".
                  _RoleCard(
                    icon: Icons.shopping_bag_outlined,
                    iconColor: const Color(0xFF0D2B5E),
                    titre: 'Je suis Client',
                    description: 'Parcourir les boutiques, commander des produits et suivre mes livraisons.',
                    badge: 'ACHETEUR',
                    badgeColor: const Color(0xFF0D2B5E),
                    selected: _selectedRole == 'customer',
                    onTap: () => setState(() => _selectedRole = 'customer'),
                    features: const ['Voir les boutiques', 'Passer des commandes', 'Suivi en temps réel'],
                  ),
                  const SizedBox(height: 14),
                  // Kat Vendeur
                  // Carte de sélection du rôle "Vendeur", même logique que
                  // la carte Client mais avec une couleur d'accent verte.
                  _RoleCard(
                    icon: Icons.storefront_outlined,
                    iconColor: const Color(0xFF1D9E75),
                    titre: 'Je suis Vendeur',
                    description: 'Créer ma boutique, gérer mes produits et traiter les commandes clients.',
                    badge: 'VENDEUR',
                    badgeColor: const Color(0xFF1D9E75),
                    selected: _selectedRole == 'seller',
                    onTap: () => setState(() => _selectedRole = 'seller'),
                    features: const ['Gérer ma boutique', 'Publier des produits', 'Traiter les commandes'],
                  ),
                  const SizedBox(height: 16),
                  // Avertissement — choix définitif (maquette : bandeau ⚠️)
                  // Bandeau jaune qui prévient l'utilisateur que le rôle
                  // choisi ne pourra pas être changé plus tard (un compte =
                  // un seul rôle).
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3D6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF5C453)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFB8860B), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Ce choix est définitif. Un vendeur ne peut pas "
                            "passer commande et vice-versa. Créez deux "
                            "comptes si nécessaire.",
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A5C00),
                                height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bouton continuer
                  // Bouton "Continuer" : désactivé (onPressed: null) tant
                  // qu'aucun rôle n'est sélectionné, ce qui grise aussi
                  // automatiquement son fond. Une fois cliqué, on navigue
                  // vers l'écran d'authentification (/auth) en transmettant
                  // le rôle choisi via `extra`. `context.go` remplace toute
                  // la pile de navigation (pas de bouton retour vers cet
                  // écran).
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedRole != null
                            ? const Color(0xFF0D2B5E)
                            : const Color(0xFFCCCCCC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _selectedRole == null
                          ? null
                          : () => context.go('/auth',
                              extra: {'role': _selectedRole}),
                      child: const Text('Continuer',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Visiteur
                  // Lien permettant de continuer sans créer de compte —
                  // redirige vers l'écran d'accueil visiteur (mode "guest",
                  // voir BF-010 dans guest_home_screen.dart).
                  TextButton(
                    onPressed: () => context.go('/guest'),
                    child: const Text('Parcourir sans s\'inscrire',
                        style: TextStyle(
                            color: Color(0xFF666666), fontSize: 13)),
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

// Widget réutilisable représentant une carte de choix de rôle (Client ou
// Vendeur). Purement visuel/stateless : tout l'état (sélection) est géré
// par le parent (_RoleSelectionScreenState) et transmis via les paramètres.
class _RoleCard extends StatelessWidget {
  final IconData icon;          // Icône affichée dans le carré coloré.
  final Color iconColor;        // Couleur d'accent de la carte (icône, bordure si sélectionnée, etc.).
  final String titre;           // Titre principal ("Je suis Client" / "Je suis Vendeur").
  final String description;     // Phrase descriptive sous le titre.
  final String badge;           // Petit badge texte ("ACHETEUR" / "VENDEUR").
  final Color badgeColor;       // Couleur du badge.
  final bool selected;          // Vrai si cette carte est actuellement sélectionnée.
  final VoidCallback onTap;     // Callback exécuté au clic sur la carte.
  final List<String> features;  // Liste des fonctionnalités affichées avec une coche.

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.titre,
    required this.description,
    required this.badge,
    required this.badgeColor,
    required this.selected,
    required this.onTap,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // Animation douce de la bordure/ombre lors du changement de
        // sélection (transition visuelle fluide entre l'état normal et
        // l'état sélectionné).
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          // Bordure plus épaisse et colorée quand la carte est sélectionnée.
          border: Border.all(
            color: selected ? iconColor : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
          // Ombre plus marquée (colorée) quand sélectionnée, sinon ombre
          // légère par défaut.
          boxShadow: selected
              ? [BoxShadow(color: iconColor.withOpacity(0.15),
                  blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne du haut : icône + titre/badge + coche de sélection.
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: selected
                                  ? iconColor
                                  : const Color(0xFF1A1F36))),
                      const SizedBox(height: 2),
                      // Badge texte (ex: "ACHETEUR") dans une pastille colorée.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badge,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
                // Icône de coche affichée uniquement si la carte est
                // sélectionnée (confirmation visuelle du choix).
                if (selected)
                  Icon(Icons.check_circle, color: iconColor, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            // Description détaillée du rôle.
            Text(description,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF666666), height: 1.4)),
            const SizedBox(height: 10),
            // Liste des fonctionnalités associées à ce rôle, générée
            // dynamiquement à partir de la liste `features` passée en
            // paramètre (une ligne icône + texte par élément).
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 13, color: iconColor),
                  const SizedBox(width: 6),
                  Text(f, style: const TextStyle(
                      fontSize: 11, color: Color(0xFF444444))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
