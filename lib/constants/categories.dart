/// Catégories produits — Faitza COLAS
/// Branch : feature/categories
/// Path : lib/constants/categories.dart
///
/// Liste fixe des catégories et de leurs sous-catégories. Utilisée :
///  - à la création / modification de la boutique (le vendeur coche les
///    catégories qu'il vend → colonne `shops.categories`)
///  - à l'ajout / modification d'un produit (dropdown catégorie limité aux
///    catégories de la boutique, puis dropdown sous-catégorie dépendant)
class Categories {
  /// Catégorie → sous-catégories, dans l'ordre d'affichage.
  static const Map<String, List<String>> sousCategories = {
    'Alimentation': ['Fruits', 'Légumes', 'Épices', 'Condiments'],
    'Mode':         ['Robes', 'Chemises', 'Pantalons', 'Chaussures'],
    'Électronique': ['Téléphones', 'Accessoires', 'Électroménager'],
    'Beauté':       ['Soins visage', 'Corps', 'Parfums', 'Coiffure'],
    'Maison':       ['Meubles', 'Décoration', 'Cuisine', 'Linge'],
    'Services':     ['Livraison', 'Réparation', 'Couture'],
  };

  /// Toutes les catégories disponibles.
  static List<String> get toutes => sousCategories.keys.toList();

  /// Sous-catégories d'une catégorie (liste vide si inconnue).
  static List<String> de(String? categorie) =>
      sousCategories[categorie] ?? const [];
}
