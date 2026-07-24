import 'package:flutter/material.dart';

/// Badge statut commande — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/order_status_badge.dart
///
/// Petit widget "pilule" (fond arrondi + bordure) affichant le statut d'une
/// commande avec une couleur et un libellé français adaptés — utilisé dans
/// les listes de commandes (client et vendeur) pour donner un repère
/// visuel rapide de l'état de la commande.
class OrderStatusBadge extends StatelessWidget {
  // Valeur brute du statut telle que stockée en base (colonne `statut` de
  // la table `orders`) : 'nouvelle', 'acceptee', 'preparation',
  // 'livraison', 'livree' ou 'annulee'.
  final String statut; // valeur Firestore : nouvelle, acceptee, etc.

  const OrderStatusBadge({super.key, required this.statut});

  /// Choisit la couleur associée à chaque statut (getter recalculé à
  /// chaque accès, pas de cache — pas un souci vu la faible fréquence
  /// d'appel). `default` couvre le cas d'un statut inconnu/inattendu.
  // Couleur de fond selon statut
  Color get _couleur {
    switch (statut) {
      case 'nouvelle':    return const Color(0xFFF5A623);
      case 'acceptee':    return const Color(0xFF0D2B5E);
      case 'preparation': return const Color(0xFF6B21A8);
      case 'livraison':   return const Color(0xFF0891B2);
      case 'livree':      return const Color(0xFF1D9E75);
      case 'annulee':     return const Color(0xFFE63946);
      default:            return const Color(0xFF999999);
    }
  }

  /// Traduit le code technique du statut (ex. 'nouvelle') en libellé
  /// affiché à l'utilisateur (ex. "En attente du vendeur") ; si le
  /// statut ne correspond à aucun cas connu, on affiche la valeur brute
  /// telle quelle en dernier recours.
  // Label affiché
  String get _label {
    switch (statut) {
      case 'nouvelle':    return 'En attente du vendeur';
      case 'acceptee':    return 'Acceptée';
      case 'preparation': return 'En préparation';
      case 'livraison':   return 'En livraison';
      case 'livree':      return 'Livrée';
      case 'annulee':     return 'Annulée';
      default:            return statut;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Container en forme de pilule : fond légèrement transparent
    // (opacité 15%) de la couleur du statut, bordure pleine opacité de la
    // même couleur, coins très arrondis (20px) pour l'effet "badge".
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _couleur.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _couleur, width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _couleur,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}