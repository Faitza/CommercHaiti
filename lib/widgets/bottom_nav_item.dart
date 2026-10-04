import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/theme_provider.dart';

/// Bouton de la barre de navigation du bas (Accueil / Panier / Commandes,
/// et barre du vendeur). Partagé par tous les écrans pour que la taille,
/// les couleurs (clair et sombre) et la pastille soient les mêmes partout.
///
/// [badge] : nombre affiché dans une pastille rouge sur l'icône (ex.
/// nombre d'articles du panier) ; rien n'est affiché si 0.
class BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  const BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final color = active
        ? AppColors.accentFor(isDark)
        : AppColors.textSecondaryFor(isDark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      // Zone de toucher plus large que l'icône, pour les petits écrans.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: AppColors.red,
                textColor: Colors.white,
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
