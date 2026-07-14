import 'package:flutter/material.dart';

/// Badge statut commande — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/widgets/order_status_badge.dart
class OrderStatusBadge extends StatelessWidget {
  final String statut; // valeur Firestore : nouvelle, acceptee, etc.

  const OrderStatusBadge({super.key, required this.statut});

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