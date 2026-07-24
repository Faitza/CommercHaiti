import 'package:flutter/material.dart';

/// Logo boutique — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/shop_logo_widget.dart
/// Affiche photo si logoURL existe, sinon initiales colorées
///
/// Widget réutilisable partout où une boutique est représentée visuellement
/// (liste de boutiques, en-tête vendeur, etc.) : affiche la vraie photo du
/// logo si elle a été uploadée, sinon un "avatar" de secours avec les
/// initiales du nom de la boutique sur un fond coloré — comme les avatars
/// par défaut de nombreuses apps (Gmail, Slack...).
class ShopLogoWidget extends StatelessWidget {
  // URL publique du logo (Supabase Storage) ; peut être null ou vide si la
  // boutique n'a pas encore uploadé de logo.
  final String? logoURL;
  // Initiales à afficher en secours (ex. "AB" pour une boutique nommée
  // "Atelier Boutik").
  final String initiales;
  // Taille (largeur = hauteur, le widget est toujours carré) en pixels
  // logiques ; permet de réutiliser le widget en petit (liste) ou grand
  // (en-tête) format.
  final double size;

  const ShopLogoWidget({
    super.key,
    this.logoURL,
    required this.initiales,
    this.size = 50,
  });

  /// Détermine une couleur de fond "déterministe" à partir de la première
  /// lettre des initiales : on prend le code Unicode du premier caractère
  /// modulo le nombre de couleurs disponibles, ce qui donne TOUJOURS la
  /// même couleur pour les mêmes initiales (pas de hasard/random), tout en
  /// répartissant les boutiques sur une palette de 6 couleurs distinctes.
  // Couleur de fond selon initiales (déterministe)
  Color _couleurFond() {
    final couleurs = [
      const Color(0xFF0D2B5E),
      const Color(0xFF1D6A3A),
      const Color(0xFF6B21A8),
      const Color(0xFF0891B2),
      const Color(0xFF7A4F00),
      const Color(0xFF8B1A1A),
    ];
    final index = initiales.codeUnitAt(0) % couleurs.length;
    return couleurs[index];
  }

  @override
  Widget build(BuildContext context) {
    // Carré aux coins arrondis (20% de la taille) qui coupe son contenu
    // (clipBehavior) pour que l'image réseau respecte bien la forme
    // arrondie même si elle dépasse.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        color: _couleurFond(),
      ),
      clipBehavior: Clip.antiAlias,
      // Si une URL de logo existe et n'est pas vide, on tente de charger
      // l'image réseau ; `errorBuilder` prend le relais avec les initiales
      // si le chargement échoue (URL invalide, pas de connexion...).
      // Sinon (pas d'URL), on affiche directement les initiales.
      child: logoURL != null && logoURL!.isNotEmpty
          ? Image.network(
              logoURL!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialesWidget(),
            )
          : _initialesWidget(),
    );
  }

  /// Construit le contenu de secours : les 2 premiers caractères des
  /// initiales (tronqués si plus longs), centrés, en blanc gras, avec une
  /// taille de police proportionnelle à `size` pour rester lisible à
  /// n'importe quelle taille de widget.
  Widget _initialesWidget() => Center(
        child: Text(
          initiales.length > 2 ? initiales.substring(0, 2) : initiales,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      );
}