import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';

/// Ouvre l'écran correspondant à une notification, que le tap vienne de
/// l'écran Notifications ou d'une notification push.
///
/// - nouvelle commande (vendeur)          → /vendor/orders
/// - commande annulée par le client       → /vendor/orders (côté vendeur)
/// - changement de statut (client)        → /order-tracking
/// - nouveau produit d'une boutique favorite → /client/product
Future<void> ouvrirNotification(
  GoRouter router, {
  required String type,
  required Map<String, dynamic> data,
  required bool isSeller,
}) async {
  final orderId = data['order_id']?.toString();
  final productId = data['product_id']?.toString();

  if (type == 'nouvelle_commande' || (type == 'statut_commande' && isSeller)) {
    router.push('/vendor/orders');
    return;
  }

  if (type == 'statut_commande' && orderId != null) {
    router.push('/order-tracking',
        extra: {'orderId': orderId, 'vendeurTelephone': ''});
    return;
  }

  if (type == 'nouveau_produit' && productId != null) {
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();
      if (row == null) return;
      router.push('/client/product',
          extra: ProductModel.fromMap(row, productId));
    } catch (e) {
      debugPrint('ouvrirNotification: $e');
    }
  }
}
