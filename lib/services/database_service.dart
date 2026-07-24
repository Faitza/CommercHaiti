import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/review_model.dart';

/// Service base de données Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/database_service.dart
///
/// Cette classe centralise TOUTES les requêtes SQL (via l'API Postgrest de
/// Supabase) faites par l'application : création/lecture/mise à jour de
/// lignes dans les tables `users`, `shops`, `products`, `orders`,
/// `reviews`. Chaque table Postgres correspond à un modèle Dart
/// (UserModel, ShopModel, etc.) avec des méthodes `toMap()`/`fromMap()`
/// pour convertir entre objets Dart et lignes JSON renvoyées par Supabase.
class DatabaseService {
  // Instance unique (singleton) du client Supabase initialisé au
  // démarrage de l'app (voir main.dart) ; permet d'appeler .from(), .rpc(),
  // .auth., .storage. sans le repasser en paramètre partout.
  final _supabase = Supabase.instance.client;

  // ════════════════════════════════════
  // USERS
  // ════════════════════════════════════

  /// Insère une nouvelle ligne dans la table `users` à partir d'un
  /// UserModel converti en Map (colonnes SQL). Utilisé après l'inscription.
  Future<void> createUser(UserModel user) async {
    await _supabase.from('users').insert(user.toMap());
  }

  /// Récupère un utilisateur par son id (uid = clé primaire = même id que
  /// dans Supabase Auth). `.single()` attend exactement une ligne et lève
  /// une exception si 0 ou plusieurs lignes sont trouvées — d'où le
  /// try/catch qui retourne `null` si l'utilisateur n'existe pas.
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

  /// Met à jour uniquement les champs fournis dans `data` (update partiel)
  /// pour la ligne dont l'id correspond à `uid`.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _supabase.from('users').update(data).eq('id', uid);
  }

  // ════════════════════════════════════
  // SHOPS
  // ════════════════════════════════════

  /// Crée une boutique et retourne l'id généré par Postgres.
  /// `.select('id').single()` après `.insert()` permet de récupérer la
  /// ligne insérée (Postgrest ne renvoie rien par défaut après un insert) —
  /// ici on ne demande que la colonne `id` pour limiter les données reçues.
  Future<String> createShop(ShopModel shop) async {
    final response = await _supabase
        .from('shops')
        .insert(shop.toMap())
        .select('id')
        .single();
    return response['id'] as String;
  }

  /// Met à jour les champs fournis pour la boutique `shopId`.
  Future<void> updateShop(String shopId, Map<String, dynamic> data) async {
    await _supabase.from('shops').update(data).eq('id', shopId);
  }

  /// Récupère une boutique par son id ; retourne `null` si introuvable.
  Future<ShopModel?> getShop(String shopId) async {
    try {
      final row = await _supabase
          .from('shops')
          .select()
          .eq('id', shopId)
          .single();
      return ShopModel.fromMap(row, row['id']);
    } catch (e) {
      return null;
    }
  }

  // ════════════════════════════════════
  // PRODUCTS
  // ════════════════════════════════════

  /// Crée un produit et retourne son id généré (même logique que
  /// createShop : on relit l'id juste après l'insertion).
  Future<String> createProduct(ProductModel product) async {
    final response = await _supabase
        .from('products')
        .insert(product.toMap())
        .select('id')
        .single();
    return response['id'] as String;
  }

  /// Met à jour partiellement un produit (ex. prix, stock, disponibilité).
  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    await _supabase.from('products').update(data).eq('id', productId);
  }

  /// Supprime définitivement un produit de la table `products`.
  Future<void> deleteProduct(String productId) async {
    await _supabase.from('products').delete().eq('id', productId);
  }

  /// Récupère les produits les plus vendus toutes boutiques confondues
  /// (utilisé par ex. sur l'accueil client). On ne garde que les produits
  /// `disponible = true` et on trie par `total_commandes` décroissant
  /// (le produit le plus commandé en premier), limité à `limit` résultats.
  Future<List<ProductModel>> getTopProducts({int limit = 10}) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('disponible', true)
        .order('total_commandes', ascending: false)
        .limit(limit);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  /// Top produits d'UNE boutique (dashboard/stats vendeur — BF-032).
  /// Même logique que getTopProducts mais filtrée sur `shop_id` — sert au
  /// vendeur à voir ses articles les plus populaires dans son tableau de
  /// bord.
  Future<List<ProductModel>> getTopProductsForShop(String shopId,
      {int limit = 5}) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('shop_id', shopId)
        .order('total_commandes', ascending: false)
        .limit(limit);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  /// Les 5 produits les MOINS vendus d'une boutique (tri ascendant au lieu
  /// de descendant) — aide le vendeur à repérer les articles qui se
  /// vendent mal.
  Future<List<ProductModel>> getFlop5Products(String shopId) async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('shop_id', shopId)
        .order('total_commandes', ascending: true)
        .limit(5);
    return rows.map((row) => ProductModel.fromMap(row, row['id'])).toList();
  }

  /// Produits en stock faible (entre 1 et 5 unités restantes, exclusif de
  /// 0 = rupture totale). `.lte('stock', 5)` = stock <= 5 et
  /// `.gt('stock', 0)` = stock > 0, combinés pour cibler la zone
  /// "à réapprovisionner bientôt" sans inclure les produits déjà épuisés.
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

  /// Crée une commande en appelant la fonction Postgres `create_order_atomic`
  /// via `.rpc()` (Remote Procedure Call) au lieu d'un simple `.insert()`.
  ///
  /// Pourquoi une RPC et pas un insert direct ? Une commande implique
  /// PLUSIEURS opérations qui doivent réussir ou échouer ENSEMBLE (créer la
  /// ligne `orders`, créer les lignes `order_items`, décrémenter le stock
  /// du produit) : c'est une transaction atomique. En faisant tout ça côté
  /// serveur dans une seule fonction SQL, on garantit qu'aucune commande
  /// n'est créée si le stock est insuffisant (pas de "race condition" entre
  /// deux clients qui commanderaient en même temps le dernier article).
  /// La fonction retourne l'id (String) de la commande créée.
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
        // Les paramètres sont préfixés "p_" côté SQL (convention pour les
        // distinguer des colonnes de table) ; on les passe ici sous forme
        // de Map nom_param -> valeur.
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
      // La fonction SQL lève une exception contenant le mot-clé
      // 'stock_insuffisant' quand la quantité demandée dépasse le stock
      // disponible ; on la traduit en Exception Dart au message stable
      // pour que l'UI puisse afficher un message clair au client, sans
      // dépendre du texte exact renvoyé par Postgres.
      if (e.message.contains('stock_insuffisant')) {
        throw Exception('stock_insuffisant');
      }
      // Toute autre erreur Postgrest est simplement propagée telle quelle.
      rethrow;
    }
  }

  /// Change le statut d'une commande (ex. 'acceptee', 'preparation',
  /// 'livraison', 'livree'...) — update simple d'une seule colonne.
  Future<void> updateOrderStatus(String orderId, String newStatut) async {
    await _supabase
        .from('orders')
        .update({'statut': newStatut})
        .eq('id', orderId);
  }

  /// Annule une commande, mais UNIQUEMENT si elle est encore au statut
  /// 'nouvelle' (pas encore acceptée par le vendeur). On relit d'abord le
  /// statut actuel pour valider cette règle métier côté client avant
  /// d'écrire — évite d'annuler une commande déjà en cours de préparation
  /// ou livrée.
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

  /// Insère un avis client (note + commentaire) pour une boutique.
  Future<void> createReview(ReviewModel review) async {
    await _supabase.from('reviews').insert(review.toMap());
    // Note moyenne calculée automatiquement par trigger SQL
    // (pas besoin de la recalculer manuellement côté Dart : un trigger
    // Postgres met à jour la moyenne de la boutique dès qu'un avis est
    // inséré/modifié/supprimé).
  }
}