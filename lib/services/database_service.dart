import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/review_model.dart';

/// Service base de données Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/database_service.dart
class DatabaseService {
  final _supabase = Supabase.instance.client;

  // ════════════════════════════════════
  // USERS
  // ════════════════════════════════════

  Future<void> createUser(UserModel user) async {
    await _supabase.from('users').insert(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .single();
      return UserModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // ════════════════════════════════════
  // SHOPS
  // ════════════════════════════════════

  Future<String> createShop(ShopModel shop) async {
    final response = await _supabase
        .from('shops')
        .insert(shop.toMap())
        .select('id')
        .single();
    return response['id'] as String;
  }

  Future<void> updateShop(String shopId, Map<String, dynamic> data) async {
    await _supabase.from('shops').update(data).eq('id', shopId);
  }

  // ════════════════════════════════════
  // PRODUCTS
  // ════════════════════════════════════

  Future<String> createProduct(ProductModel product) async {
    final response = await _supabase
        .from('products')
        .insert(product.toMap())
        .select('id')
        .single();
    return response['id'] as String;
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    await _supabase.from('products').update(data).eq('id', productId);
  }

  Future<void> deleteProduct(String productId) async {
    await _supabase.from('products').delete().eq('id', productId);
  }

  Future<List<ProductModel>> getTopProducts({int limit = 10}) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('disponible', true)
        .order('total_commandes', ascending: false)
        .limit(limit);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  Future<List<ProductModel>> getFlop5Products(String shopId) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('shop_id', shopId)
        .order('total_commandes', ascending: true)
        .limit(5);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  Future<List<ProductModel>> getLowStockProducts(String shopId) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('shop_id', shopId)
        .lte('stock', 5)
        .gt('stock', 0);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  // ════════════════════════════════════
  // ORDERS — TRANSACTION ATOMIQUE ⚡
  // ════════════════════════════════════

  Future<String> createOrder({
    required OrderModel order,
    required String productId,
    required int quantite,
    required String nomProduit,
    required double prixProduit,
    String? couleur,
    String? taille,
  }) async {
    try {
      final response = await _supabase.rpc(
        'create_order_atomic',
        params: {
          'p_client_id':         order.clientId,
          'p_shop_id':           order.shopId,
          'p_seller_id':         order.sellerId,
          'p_product_id':        productId,
          'p_quantite':          quantite,
          'p_total':             order.total,
          'p_adresse_livraison': order.adresseLivraison,
          'p_zone':              order.zone,
          'p_telephone_client':  order.telephoneClient,
          'p_nom_produit':       nomProduit,
          'p_prix_produit':      prixProduit,
          'p_couleur':           couleur,
          'p_taille':            taille,
          'p_note_vendeur':      order.noteVendeur,
        },
      );
      return response as String;
    } on PostgrestException catch (e) {
      if (e.message.contains('stock_insuffisant')) {
        throw Exception('stock_insuffisant');
      }
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatut) async {
    await _supabase
        .from('orders')
        .update({'statut': newStatut})
        .eq('id', orderId);
  }

  Future<void> cancelOrder(String orderId) async {
    final order = await _supabase
        .from('orders')
        .select('statut')
        .eq('id', orderId)
        .single();

    if (order['statut'] != 'nouvelle') {
      throw Exception('Annulation impossible');
    }

    await _supabase
        .from('orders')
        .update({'statut': 'annulee'})
        .eq('id', orderId);
  }

  // ════════════════════════════════════
  // REVIEWS
  // ════════════════════════════════════

  Future<void> createReview(ReviewModel review) async {
    await _supabase.from('reviews').insert(review.toMap());
    // Note moyenne calculée automatiquement par trigger SQL
  }
}