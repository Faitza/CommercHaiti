import 'package:flutter/material.dart';

/// Couleurs de l'application — Falexson MERCIVAL
/// Branch : feature/ui-settings
/// Path : lib/constants/app_colors.dart
/// IMPORTANT : toujours utiliser AppColors.navy au lieu de Color(0xFF0D2B5E)
// Classe utilitaire centralisant TOUTES les couleurs de l'application.
// Objectif : éviter de disperser des codes hexadécimaux (Color(0xFF...))
// dans chaque écran — si la charte graphique change, il suffit de modifier
// les valeurs ici plutôt que de chercher chaque occurrence dans le code.
// Tous les champs sont `static const` : ce sont des constantes de
// compilation, partagées par toute l'application sans être recréées.
class AppColors {
  // Couleurs principales
  // Bleu marine principal — couleur de marque de CommercHaiti (header,
  // boutons principaux, AppBar...).
  static const Color navy      = Color(0xFF0D2B5E);
  // Variante plus foncée du bleu marine, utilisée en mode sombre.
  static const Color darkNavy  = Color(0xFF061A3A);
  // Rouge d'accent — utilisé pour les alertes, badges "urgent", boutons
  // secondaires (ex. "S'inscrire").
  static const Color red       = Color(0xFFE63946);

  // Couleurs secondaires
  // Vert — utilisé pour représenter le rôle "Vendeur" et les statuts
  // positifs (ex. boutique ouverte, commande livrée).
  static const Color green     = Color(0xFF1D9E75);
  // Orange/ambre — utilisé pour les étoiles de notation et alertes légères.
  static const Color amber     = Color(0xFFF5A623);
  // Vert WhatsApp — utilisé spécifiquement pour les boutons de contact via
  // WhatsApp (couleur de la marque WhatsApp).
  static const Color whatsapp  = Color(0xFF25D366);

  // Fonds
  // Couleurs de fond utilisées pour le corps des écrans et divers
  // encadrés/bannières colorées.
  static const Color background = Color(0xFFF2F4F8);
  static const Color lightBlue  = Color(0xFFEEF3FB);
  static const Color lightGreen = Color(0xFFE8F5EE);
  static const Color lightRed   = Color(0xFFFDEAEA);
  static const Color lightAmber = Color(0xFFFEF3E0);

  // Textes
  // Palette de couleurs de texte, du plus foncé (titre) au plus clair
  // (placeholder).
  static const Color textPrimary   = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint      = Color(0xFFAAAAAA);

  // Statuts commande
  // Une couleur dédiée par étape du cycle de vie d'une commande, pour que
  // l'utilisateur reconnaisse visuellement l'état d'une commande d'un
  // coup d'œil (badges de statut dans les écrans de suivi/historique).
  static const Color statusNew       = Color(0xFFF5A623); // Nouvelle
  static const Color statusAccepted  = Color(0xFF0D2B5E); // Acceptée
  static const Color statusPreparing = Color(0xFF6B21A8); // En préparation
  static const Color statusDelivering= Color(0xFF0891B2); // En livraison
  static const Color statusDelivered = Color(0xFF1D9E75); // Livrée
  static const Color statusCancelled = Color(0xFFE63946); // Annulée

  // Mode sombre — helpers utilisés par les écrans principaux
  // (fond de page, cartes/surfaces, texte) selon ThemeProvider.isDarkMode.
  // Ces fonctions prennent un booléen `isDark` (fourni par ThemeProvider)
  // et retournent la couleur adaptée au thème actif, évitant de dupliquer
  // des `if (isDark) ... else ...` dans chaque écran.

  // Couleur de fond du Scaffold : gris très foncé en mode sombre, gris
  // clair (background) en mode clair.
  static Color scaffoldBg(bool isDark) =>
      isDark ? const Color(0xFF121212) : background;
  // Couleur des surfaces/cartes (au-dessus du fond) : gris foncé en mode
  // sombre, blanc en mode clair.
  static Color surface(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.white;
  // Couleur du texte principal : blanc en mode sombre, bleu marine foncé
  // (textPrimary) en mode clair.
  static Color textPrimaryFor(bool isDark) =>
      isDark ? Colors.white : textPrimary;
  // Couleur du texte secondaire : blanc semi-transparent en mode sombre,
  // gris (textSecondary) en mode clair.
  static Color textSecondaryFor(bool isDark) =>
      isDark ? Colors.white60 : textSecondary;
}
