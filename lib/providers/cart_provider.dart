import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';

/// Panier en mémoire — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/providers/cart_provider.dart
class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get totalArticles => _items.fold(0, (sum, i) => sum + i.quantite);

  double get totalNormal =>
      _items.fold(0, (sum, i) => sum + (i.product.prix * i.quantite));

  double get totalAvecPromo =>
      _items.fold(0, (sum, i) => sum + (i.product.prixAffiche * i.quantite));

  double get economies => totalNormal - totalAvecPromo;
  bool get hasPromo => economies > 0;

  void addItem({
    required ProductModel product,
    required int quantite,
    String? couleur,
    String? taille,
  }) {
    final index = _items.indexWhere((i) =>
        i.product.id == product.id &&
        i.couleur == couleur &&
        i.taille == taille);

    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        quantite: _items[index].quantite + quantite,
      );
    } else {
      _items.add(CartItem(
        product: product,
        quantite: quantite,
        couleur: couleur,
        taille: taille,
      ));
    }
    notifyListeners();
  }

  void updateQuantite(int index, int nouvelleQuantite) {
    if (nouvelleQuantite <= 0) {
      removeItem(index);
      return;
    }
    _items[index] = _items[index].copyWith(quantite: nouvelleQuantite);
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
 