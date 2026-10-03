import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/categories.dart';

/// Dropdowns catégorie + sous-catégorie — Faitza COLAS
/// Branch : feature/categories
/// Path : lib/widgets/categorie_dropdowns_widget.dart
///
/// Deux listes déroulantes côte à côte, utilisées dans les formulaires
/// d'ajout et de modification de produit :
///  - Catégorie : limitée aux catégories choisies par la boutique
///    (`categoriesAutorisees`).
///  - Sous-catégorie : change selon la catégorie sélectionnée (voir
///    Categories.sousCategories). Elle est remise à zéro quand la
///    catégorie change.
/// L'état (valeurs sélectionnées) est tenu par l'écran parent.
class CategorieDropdownsWidget extends StatelessWidget {
  final List<String> categoriesAutorisees;
  final String? categorie;
  final String? sousCategorie;
  final ValueChanged<String?> onCategorieChanged;
  final ValueChanged<String?> onSousCategorieChanged;
  final bool isDark;

  const CategorieDropdownsWidget({
    super.key,
    required this.categoriesAutorisees,
    required this.categorie,
    required this.sousCategorie,
    required this.onCategorieChanged,
    required this.onSousCategorieChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Un produit ancien peut avoir une valeur saisie en texte libre qui
    // n'est pas dans la liste : on l'ajoute aux choix pour qu'elle reste
    // affichée (sinon DropdownButtonFormField lève une erreur).
    final categories = [
      ...categoriesAutorisees,
      if (categorie != null &&
          categorie!.isNotEmpty &&
          !categoriesAutorisees.contains(categorie))
        categorie!,
    ];
    final sousCategoriesConnues = Categories.de(categorie);
    final sousCategories = [
      ...sousCategoriesConnues,
      if (sousCategorie != null &&
          sousCategorie!.isNotEmpty &&
          !sousCategoriesConnues.contains(sousCategorie))
        sousCategorie!,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Catégorie *'),
            DropdownButtonFormField<String>(
              // `key` dépendant de la valeur : force la reconstruction du
              // champ quand le parent change la valeur (chargement async).
              key: ValueKey('cat-$categorie'),
              initialValue: categorie?.isEmpty ?? true ? null : categorie,
              isExpanded: true,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: onCategorieChanged,
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              decoration: _deco('Choisir'),
            ),
          ],
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Sous-catégorie *'),
            DropdownButtonFormField<String>(
              // La clé inclut la catégorie : changer de catégorie recrée
              // ce champ avec la nouvelle liste de sous-catégories.
              key: ValueKey('sous-$categorie-$sousCategorie'),
              initialValue:
                  sousCategorie?.isEmpty ?? true ? null : sousCategorie,
              isExpanded: true,
              items: sousCategories
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              // Désactivé tant qu'aucune catégorie n'est choisie.
              onChanged: categorie == null || categorie!.isEmpty
                  ? null
                  : onSousCategorieChanged,
              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              decoration: _deco(categorie == null || categorie!.isEmpty
                  ? 'Catégorie d\'abord'
                  : 'Choisir'),
            ),
          ],
        )),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryFor(isDark))),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondaryFor(isDark)),
        filled: true,
        fillColor: AppColors.inputFill(isDark),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      );
}
