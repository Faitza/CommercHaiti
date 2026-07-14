// ignore_for_file: avoid_print
// TODO Falexson : décommenter quand Firebase sera configuré
// import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/review_model.dart';

/// Service Firestore — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/firestore_service.dart
/// SEUL fichier qui parle à Firestore
/// Contient la TRANSACTION ATOMIQUE pour les commandes
class FirestoreService {
  // final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ════════════════════════════════════
  // USERS
  // ════════════════════════════════════

  Future<void> createUser(UserModel user) async {
    try {
      // TODO :
      // await _db.collection('users').doc(user.uid).set(user.toMap());

      // ── DONNÉES TEST ──
      print('[TEST] Utilisateur créé : ${user.nom}');
    } catch (e) {
      print('Erreur createUser: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      // TODO :
      // final doc = await _db.collection('users').doc(uid).get();
      // if (doc.exists) return UserModel.fromMap(doc.data()!);

      // ── DONNÉES TEST ──
      return null;
    } catch (e) {
      print('Erreur getUser: $e');
      return null;
    }
  }

  // ════════════════════════════════════
  // SHOPS
  // ════════════════════════════════════

  Future<String> createShop(ShopModel shop) async {
    try {
      // TODO :
      // final ref = await _db.collection('shops').add(shop.toMap());
      // return ref.id;

      // ── DONNÉES TEST ──
      print('[TEST] Boutique créée : ${shop.nom}');
      return 'test_shop_id';
    } catch (e) {
      print('Erreur createShop: $e');
      rethrow;
    }
  }

  Stream<List<ShopModel>> getShops() {
    // TODO :
    // return _db
    //   .collection('shops')
    //   .where('isOpen', isEqualTo: true)
    //   .snapshots()
    //   .map((snap) => snap.docs
    //     .map((doc) => ShopModel.fromMap(doc.data(), doc.id))
    //     .toList());

    // ── DONNÉES TEST ──
    return Stream.value([
      ShopModel(
        id: 'shop_test_1',
        proprietaireId: 'seller_uid',
        nom: 'Marché Frais Lakay',
        description: 'Fruits, légumes et produits locaux frais',
        shopCode: 'MFL-2026-4892',
        zonesLivraison: [
          ZoneLivraison(zone: 'Cayes Centre', delaiMin: 20, delaiMax: 30),
          ZoneLivraison(zone: 'Cayes Nord', delaiMin: 30, delaiMax: 45),
        ],
        rating: 4.5,
        totalAvis: 23,
        isOpen: true,
        createdAt: DateTime.now(),
      ),
      ShopModel(
        id: 'shop_test_2',
        proprietaireId: 'seller_uid_2',
        nom: 'Mode Elegance',
        description: 'Vêtements et accessoires tendance',
        shopCode: 'ME-2026-1234',
        zonesLivraison: [
          ZoneLivraison(zone: 'Cayes Centre', delaiMin: 15, delaiMax: 25),
        ],
        rating: 4.2,
        totalAvis: 15,
        isOpen: true,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  Future<void> updateShop(String shopId, Map<String, dynamic> data) async {
    // TODO :
    // await _db.collection('shops').doc(shopId).update(data);
    print('[TEST] Boutique mise à jour : $shopId');
  }

  // ════════════════════════════════════
  // PRODUCTS
  // ════════════════════════════════════

  Future<String> createProduct(ProductModel product) async {
    try {
      // TODO :
      // final ref = await _db
      //   .collection('shops').doc(product.shopId)
      //   .collection('products').add(product.toMap());
      // return ref.id;

      print('[TEST] Produit créé : ${product.nom}');
      return 'test_product_id';
    } catch (e) {
      print('Erreur createProduct: $e');
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProducts(String shopId) {
    // TODO :
    // return _db
    //   .collection('shops').doc(shopId)
    //   .collection('products')
    //   .where('disponible', isEqualTo: true)
    //   .snapshots()
    //   .map((snap) => snap.docs
    //     .map((doc) => ProductModel.fromMap(doc.data(), doc.id))
    //     .toList());

    // ── DONNÉES TEST ──
    return Stream.value([
      ProductModel(
        id: 'product_test_1',
        shopId: shopId,
        nom: 'Robe Fleurie',
        prix: 1500,
        prixPromo: 1200,
        photos: [],
        stock: 8,
        categorie: 'Mode',
        sousCategorie: 'Robes',
        tailles: ['S', 'M', 'L', 'XL'],
        couleurs: ['FF5733', '2ECC71', '3498DB'],
        disponible: true,
        totalCommandes: 42,
        createdAt: DateTime.now(),
      ),
      ProductModel(
        id: 'product_test_2',
        shopId: shopId,
        nom: 'Banane Plantain (kg)',
        prix: 250,
        photos: [],
        stock: 3,
        categorie: 'Alimentation',
        sousCategorie: 'Fruits',
        disponible: true,
        totalCommandes: 118,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  Future<void> updateProduct(
      String shopId, String productId, Map<String, dynamic> data) async {
    // TODO :
    // await _db.collection('shops').doc(shopId)
    //   .collection('products').doc(productId).update(data);
    print('[TEST] Produit mis à jour : $productId');
  }

  Future<void> deleteProduct(String shopId, String productId) async {
    // TODO :
    // await _db.collection('shops').doc(shopId)
    //   .collection('products').doc(productId).delete();
    print('[TEST] Produit supprimé : $productId');
  }

  // ════════════════════════════════════
  // ORDERS — TRANSACTION ATOMIQUE ⚡
  // ════════════════════════════════════

  /// Crée une commande avec transaction atomique
  /// Stock-- ET création commande en même temps — TOUT ou RIEN
  Future<String> createOrder({
    required OrderModel order,
    required String shopId,
    required String productId,
    required int quantite,
  }) async {
    try {
      // TODO :
      // final productRef = _db
      //   .collection('shops').doc(shopId)
      //   .collection('products').doc(productId);
      // final orderRef = _db.collection('orders').doc();
      //
      // await _db.runTransaction((transaction) async {
      //   // ÉTAPE 1 : Lire stock dans la transaction
      //   final productSnap = await transaction.get(productRef);
      //   final currentStock = productSnap.data()!['stock'] as int;
      //
      //   // ÉTAPE 2 : Vérifier stock
      //   if (currentStock < quantite) {
      //     throw Exception('Stock insuffisant');
      //   }
      //
      //   // ÉTAPE 3 : Décrémenter stock ET créer commande (ensemble)
      //   transaction.update(productRef, {
      //     'stock': currentStock - quantite,
      //     'totalCommandes': FieldValue.increment(quantite),
      //   });
      //   transaction.set(orderRef, order.toMap());
      // });
      //
      // return orderRef.id;

      // ── DONNÉES TEST ──
      await Future.delayed(const Duration(milliseconds: 500));
      final orderId = 'order_test_${DateTime.now().millisecondsSinceEpoch}';
      print('[TEST] Commande créée : $orderId');
      return orderId;
    } catch (e) {
      print('Erreur createOrder: $e');
      rethrow;
    }
  }

  /// Mettre à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, String newStatut) async {
    try {
      // TODO :
      // await _db.collection('orders').doc(orderId).update({
      //   'statut': newStatut,
      // });

      print('[TEST] Statut commande $orderId → $newStatut');
    } catch (e) {
      print('Erreur updateOrderStatus: $e');
      rethrow;
    }
  }

  /// Annuler une commande — seulement si statut = nouvelle
  Future<void> cancelOrder(String orderId) async {
    try {
      // TODO :
      // final ref = _db.collection('orders').doc(orderId);
      // final snap = await ref.get();
      // if (snap.data()!['statut'] != 'nouvelle') {
      //   throw Exception('Annulation impossible — commande déjà acceptée');
      // }
      // await ref.update({'statut': 'annulee'});

      print('[TEST] Commande annulée : $orderId');
    } catch (e) {
      print('Erreur cancelOrder: $e');
      rethrow;
    }
  }

  /// Stream commandes vendeur (temps réel)
  Stream<List<OrderModel>> getOrdersForVendor(String sellerId) {
    // TODO :
    // return _db.collection('orders')
    //   .where('sellerId', isEqualTo: sellerId)
    //   .orderBy('createdAt', descending: true)
    //   .snapshots()
    //   .map((snap) => snap.docs
    //     .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
    //     .toList());

    // ── DONNÉES TEST ──
    return Stream.value([
      OrderModel(
        id: 'order_test_1',
        clientId: 'client_uid',
        shopId: 'shop_test_1',
        sellerId: sellerId,
        items: [
          OrderItem(
            productId: 'product_test_1',
            nom: 'Robe Fleurie',
            prix: 1200,
            quantite: 1,
            taille: 'M',
            couleur: 'FF5733',
          ),
        ],
        total: 1200,
        statut: 'nouvelle',
        adresseLivraison: 'Cayes Centre, Rue Republicaine',
        zone: 'Cayes Centre',
        telephoneClient: '+50937000000',
        createdAt: DateTime.now(),
      ),
    ]);
  }

  /// Stream commandes client (temps réel)
  Stream<List<OrderModel>> getOrdersForClient(String clientId) {
    // TODO :
    // return _db.collection('orders')
    //   .where('clientId', isEqualTo: clientId)
    //   .orderBy('createdAt', descending: true)
    //   .snapshots()
    //   .map((snap) => snap.docs
    //     .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
    //     .toList());

    return Stream.value([]);
  }

  // ════════════════════════════════════
  // REVIEWS
  // ════════════════════════════════════

  Future<void> createReview(ReviewModel review) async {
    try {
      // TODO :
      // await _db.collection('reviews').add(review.toMap());
      // // Mettre à jour note moyenne boutique
      // final reviews = await _db.collection('reviews')
      //   .where('shopId', isEqualTo: review.shopId).get();
      // final avg = reviews.docs
      //   .map((d) => d.data()['note'] as int)
      //   .reduce((a, b) => a + b) / reviews.docs.length;
      // await _db.collection('shops').doc(review.shopId)
      //   .update({'rating': avg, 'totalAvis': reviews.docs.length});

      print('[TEST] Avis créé pour boutique : ${review.shopId}');
    } catch (e) {
      print('Erreur createReview: $e');
      rethrow;
    }
  }

  Stream<List<ReviewModel>> getReviewsForShop(String shopId) {
    // TODO :
    // return _db.collection('reviews')
    //   .where('shopId', isEqualTo: shopId)
    //   .orderBy('createdAt', descending: true)
    //   .snapshots()
    //   .map((snap) => snap.docs
    //     .map((doc) => ReviewModel.fromMap(doc.data(), doc.id))
    //     .toList());

    return Stream.value([]);
  }
}