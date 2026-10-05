import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/categories.dart';

/// Choix des catégories vendues — Faitza COLAS
/// Branch : feature/categories
/// Path : lib/widgets/categories_boutique_widget.dart
///
/// Liste de cases à cocher (multi-sélection) des catégories disponibles
/// (voir Categories.toutes). Utilisée à la création de la boutique
/// (create_shop_screen.dart) et dans sa modification
/// (vendor_edit_shop_screen.dart). Chaque ligne rappelle les
/// sous-catégories de la catégorie. La liste `selection` appartient à
/// l'écran parent, qui est prévenu à chaque changement via `onChanged`.
class CategoriesBoutiqueWidget extends StatelessWidget {
  final List<String> selection;
  final ValueChanged<List<String>> onChanged;
  final bool isDark;

  const CategoriesBoutiqueWidget({
    super.key,
    required this.selection,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(isDark)),
      ),
      child: Column(
        children: Categories.toutes.map((cat) {
          final coche = selection.contains(cat);
          return CheckboxListTile(
            value: coche,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.navy,
            title: Text(cat,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryFor(isDark))),
            subtitle: Text(Categories.de(cat).join(', '),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryFor(isDark))),
            onChanged: (v) {
              // On garde l'ordre officiel de Categories.toutes.
              final nouvelle = Categories.toutes
                  .where((c) => c == cat ? v == true : selection.contains(c))
                  .toList();
              onChanged(nouvelle);
            },
          );
        }).toList(),
      ),
    );
  }
}
