import 'package:flutter/material.dart';

/// Couleurs de l'application — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/constants/app_colors.dart
/// IMPORTANT : toujours utiliser AppColors.navy au lieu de Color(0xFF0D2B5E)
class AppColors {
  // Couleurs principales
  static const Color navy      = Color(0xFF0D2B5E);
  static const Color darkNavy  = Color(0xFF061A3A);
  static const Color red       = Color(0xFFE63946);

  // Couleurs secondaires
  static const Color green     = Color(0xFF1D9E75);
  static const Color amber     = Color(0xFFF5A623);
  static const Color whatsapp  = Color(0xFF25D366);

  // Fonds
  static const Color background = Color(0xFFF2F4F8);
  static const Color lightBlue  = Color(0xFFEEF3FB);
  static const Color lightGreen = Color(0xFFE8F5EE);
  static const Color lightRed   = Color(0xFFFDEAEA);
  static const Color lightAmber = Color(0xFFFEF3E0);

  // Textes
  static const Color textPrimary   = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint      = Color(0xFFAAAAAA);

  // Statuts commande
  static const Color statusNew       = Color(0xFFF5A623); // Nouvelle
  static const Color statusAccepted  = Color(0xFF0D2B5E); // Acceptée
  static const Color statusPreparing = Color(0xFF6B21A8); // En préparation
  static const Color statusDelivering= Color(0xFF0891B2); // En livraison
  static const Color statusDelivered = Color(0xFF1D9E75); // Livrée
  static const Color statusCancelled = Color(0xFFE63946); // Annulée
}