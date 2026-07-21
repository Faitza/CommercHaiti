import '../models/product_model.dart';

/// Modèle article panier — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/models/cart_item_model.dart
/// IMPORTANT : panier en mémoire seulement — pas dans Supabase
class CartItem {
  final ProductModel product;
  final int quantite;
  final String? couleur;
  final String? taille;

  const CartItem({
    required this.product,
    required this.quantite,
    this.couleur,
    this.taille,
  });

  double get sousTotal => product.prixAffiche * quantite;

  CartItem copyWith({
    ProductModel? product,
    int? quantite,
    String? couleur,
    String? taille,
  }) {
    return CartItem(
      product:  product  ?? this.product,
      quantite: quantite ?? this.quantite,
      couleur:  couleur  ?? this.couleur,
      taille:   taille   ?? this.taille,
    );
  }
}
