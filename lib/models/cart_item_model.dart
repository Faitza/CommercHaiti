import '../models/product_model.dart';

/// Modèle article panier — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/models/cart_item_model.dart
/// IMPORTANT : panier en mémoire seulement — pas dans Supabase
///
/// Représente UNE ligne du panier d'achat (un produit + sa quantité +
/// les variantes choisies par le client, comme la couleur ou la taille).
/// Cette classe ne vit que dans la RAM de l'application (voir CartProvider) :
/// elle n'est jamais écrite dans la base de données tant que la commande
/// n'est pas validée. C'est seulement au moment de "createOrder" que ces
/// données sont converties en OrderItem et envoyées à Supabase.
class CartItem {
  /// Le produit ajouté au panier (référence complète vers ProductModel,
  /// donc on a accès au nom, prix, photos, stock, etc.).
  final ProductModel product;

  /// Quantité choisie par le client pour ce produit (et cette variante).
  final int quantite;

  /// Couleur choisie par le client, si le produit propose des couleurs.
  /// Nullable car tous les produits n'ont pas forcément de couleurs.
  final String? couleur;

  /// Taille choisie par le client, si le produit propose des tailles.
  /// Nullable pour la même raison que couleur.
  final String? taille;

  /// Constructeur constant — tous les champs obligatoires sauf
  /// couleur/taille qui sont optionnels (produits sans variantes).
  const CartItem({
    required this.product,
    required this.quantite,
    this.couleur,
    this.taille,
  });

  /// Sous-total de cette ligne de panier = prix affiché du produit
  /// (prix promo si disponible, sinon prix normal) multiplié par la
  /// quantité. Getter calculé à la volée, jamais stocké, pour éviter
  /// toute désynchronisation si le prix du produit change.
  double get sousTotal => product.prixAffiche * quantite;

  /// Crée une copie de cet article en remplaçant seulement les champs
  /// fournis (pattern immutable classique en Dart). Utilisé notamment
  /// par CartProvider pour modifier la quantité d'un article existant
  /// sans devoir reconstruire tous ses champs à la main.
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
