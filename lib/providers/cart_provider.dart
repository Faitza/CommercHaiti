import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

/// Panier en mémoire — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/providers/cart_provider.dart
///
/// Gère l'état du panier d'achat pour toute l'application, via le
/// pattern Provider/ChangeNotifier de Flutter : chaque widget qui écoute
/// ce provider est automatiquement reconstruit quand notifyListeners()
/// est appelé (ex : après un ajout/suppression d'article).
/// IMPORTANT : le panier n'est jamais persisté dans Supabase — il vit
/// uniquement en mémoire tant que l'app est ouverte (voir CartItem).
class CartProvider extends ChangeNotifier {
  /// Liste privée des articles du panier. Privée pour forcer l'accès en
  /// lecture seule depuis l'extérieur via le getter `items` ci-dessous.
  final List<CartItem> _items = [];

  /// Expose la liste des articles en lecture seule (List.unmodifiable)
  /// pour empêcher le code appelant de modifier directement le panier
  /// sans passer par les méthodes dédiées (addItem, removeItem, etc.),
  /// ce qui garantirait que notifyListeners() est toujours appelé.
  List<CartItem> get items => List.unmodifiable(_items);

  /// Vrai si le panier ne contient aucun article.
  bool get isEmpty => _items.isEmpty;

  /// Nombre total d'unités dans le panier (somme des quantités de
  /// chaque ligne, pas juste le nombre de lignes).
  int get totalArticles => _items.fold(0, (sum, i) => sum + i.quantite);

  /// Total du panier calculé avec le prix NORMAL de chaque produit
  /// (sans tenir compte des promotions). Sert de référence pour
  /// calculer les économies réalisées (voir `economies` plus bas).
  double get totalNormal =>
      _items.fold(0, (sum, i) => sum + (i.product.prix * i.quantite));

  /// Total réel du panier, en utilisant le prix affiché de chaque
  /// produit (prix promo si présent, sinon prix normal). C'est le
  /// montant que le client paiera réellement.
  double get totalAvecPromo =>
      _items.fold(0, (sum, i) => sum + (i.product.prixAffiche * i.quantite));

  /// Montant économisé grâce aux promotions = différence entre le total
  /// normal et le total avec promo.
  double get economies => totalNormal - totalAvecPromo;

  /// Vrai si le client bénéficie d'au moins une promotion dans son panier.
  bool get hasPromo => economies > 0;

  /// Ajoute un produit au panier (ou augmente sa quantité si le même
  /// produit avec les mêmes variantes couleur/taille est déjà présent).
  void addItem({
    required ProductModel product,
    required int quantite,
    String? couleur,
    String? taille,
  }) {
    // On cherche si une ligne identique existe déjà : même produit ET
    // mêmes variantes (couleur/taille). Deux lignes du même produit
    // mais avec des variantes différentes restent des lignes séparées.
    final index = _items.indexWhere((i) =>
        i.product.id == product.id &&
        i.couleur == couleur &&
        i.taille == taille);

    if (index >= 0) {
      // Ligne déjà existante : on incrémente simplement la quantité
      // via copyWith (immutabilité — on remplace l'objet, pas de
      // mutation directe d'un champ final).
      _items[index] = _items[index].copyWith(
        quantite: _items[index].quantite + quantite,
      );
    } else {
      // Nouvelle combinaison produit/variantes : on ajoute une nouvelle
      // ligne au panier.
      _items.add(CartItem(
        product: product,
        quantite: quantite,
        couleur: couleur,
        taille: taille,
      ));
    }
    // Prévient tous les widgets qui écoutent ce provider de se
    // reconstruire pour refléter le nouvel état du panier.
    notifyListeners();
  }

  /// Modifie la quantité d'un article existant, identifié par son index
  /// dans la liste. Si la nouvelle quantité tombe à 0 ou moins, on
  /// supprime carrément la ligne plutôt que de garder une quantité nulle.
  void updateQuantite(int index, int nouvelleQuantite) {
    if (nouvelleQuantite <= 0) {
      removeItem(index);
      return;
    }
    _items[index] = _items[index].copyWith(quantite: nouvelleQuantite);
    notifyListeners();
  }

  /// Retire complètement un article du panier par son index.
  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  /// Vide entièrement le panier (utilisé par exemple après validation
  /// d'une commande, pour repartir d'un panier propre).
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
