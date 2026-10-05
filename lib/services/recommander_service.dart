import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

/// « Recommander » : remet dans le panier les articles d'une ancienne
/// commande, avec les prix et le stock d'aujourd'hui, puis ouvre le
/// panier. Les produits retirés, masqués ou en rupture sont ignorés (et
/// signalés) ; une quantité supérieure au stock est ramenée au stock.
Future<void> recommander(BuildContext context, OrderModel order) async {
  if (order.items.isEmpty) return;
  final cart = context.read<CartProvider>();

  // Le panier ne contient qu'une boutique à la fois : on demande avant
  // de remplacer un panier déjà rempli.
  if (!cart.isEmpty) {
    final remplacer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer le panier ?'),
        content: const Text(
            'Votre panier contient déjà des articles. Ils seront remplacés '
            'par ceux de cette commande.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer')),
        ],
      ),
    );
    if (remplacer != true || !context.mounted) return;
  }

  List<ProductModel> produits;
  try {
    final rows = await Supabase.instance.client
        .from('products')
        .select()
        .inFilter('id', order.items.map((i) => i.productId).toSet().toList());
    produits = rows.map((r) => ProductModel.fromMap(r, r['id'])).toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible de charger les produits. Réessayez.'),
        backgroundColor: AppColors.red,
      ));
    }
    return;
  }

  cart.clear();
  var ajoutes = 0;
  var ignores = 0;
  for (final item in order.items) {
    ProductModel? produit;
    for (final p in produits) {
      if (p.id == item.productId) produit = p;
    }
    if (produit == null || !produit.disponible || produit.stock <= 0) {
      ignores++;
      continue;
    }
    cart.addItem(
      product: produit,
      quantite: item.quantite.clamp(1, produit.stock),
      couleur: item.couleur,
      taille: item.taille,
    );
    ajoutes++;
  }

  if (!context.mounted) return;
  if (ajoutes == 0) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Ces produits ne sont plus disponibles."),
      backgroundColor: AppColors.red,
    ));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(ignores == 0
        ? 'Articles ajoutés au panier'
        : 'Articles ajoutés — $ignores ne sont plus disponibles'),
  ));
  context.push('/cart');
}
