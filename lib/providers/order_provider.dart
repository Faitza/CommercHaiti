import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';

/// Provider commandes — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/providers/order_provider.dart
///
/// Gère l'état des commandes pour deux points de vue à la fois : celui
/// du client (ses propres commandes) et celui du vendeur (les commandes
/// reçues dans sa boutique). Les deux listes sont maintenues séparément
/// et synchronisées en temps réel via les streams Supabase.
class OrderProvider extends ChangeNotifier {
  /// Client Supabase global, utilisé pour les requêtes/streams directs
  /// (lecture des commandes et de leurs items).
  final _supabase = Supabase.instance.client;
  /// Service dédié qui encapsule les opérations d'écriture plus
  /// complexes (création de commande via RPC, changement de statut).
  final _db = DatabaseService();

  /// Liste des commandes du client actuellement connecté.
  List<OrderModel> _ordresClient = [];
  /// Liste des commandes reçues par le vendeur actuellement connecté.
  List<OrderModel> _ordresVendeur = [];
  /// Indique si une opération asynchrone (création de commande, etc.)
  /// est en cours, pour afficher un indicateur de chargement dans l'UI.
  bool _isLoading = false;
  /// Dernier message d'erreur à afficher à l'utilisateur, ou null s'il
  /// n'y a pas d'erreur en cours.
  String? _errorMessage;

  /// Expose les commandes du client (lecture seule depuis l'extérieur).
  List<OrderModel> get ordresClient => _ordresClient;
  /// Expose les commandes du vendeur (lecture seule depuis l'extérieur).
  List<OrderModel> get ordresVendeur => _ordresVendeur;
  /// Indique si un chargement est en cours.
  bool get isLoading => _isLoading;
  /// Message d'erreur courant, à afficher dans l'UI (ex : SnackBar).
  String? get errorMessage => _errorMessage;

  /// Sous-ensemble des commandes vendeur qui sont encore "nouvelle",
  /// c'est-à-dire pas encore traitées — sert à afficher un badge de
  /// notification/compteur de commandes en attente pour le vendeur.
  List<OrderModel> get enAttente =>
      _ordresVendeur.where((o) => o.statut == 'nouvelle').toList();

  /// Écouter commandes client en temps réel
  /// Ouvre un flux (stream) Supabase sur la table orders filtré par
  /// client_id : chaque fois qu'une commande de ce client est créée ou
  /// modifiée côté serveur, ce callback est redéclenché automatiquement
  /// (grâce à Supabase Realtime), sans qu'on ait besoin de rafraîchir
  /// manuellement.
  void listenClientOrders(String clientId) {
    _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .listen((data) async {
          final orders = <OrderModel>[];
          // Pour chaque commande reçue, on va chercher séparément ses
          // articles (order_items) car le stream Supabase ne fait pas
          // de jointure automatique — chaque commande doit donc être
          // enrichie manuellement avec ses items avant d'être ajoutée.
          for (final row in data) {
            final items = await _getOrderItems(row['id']);
            orders.add(OrderModel.fromMap(row, row['id'], items: items));
          }
          _ordresClient = orders;
          notifyListeners();
        });
  }

  /// Écouter commandes vendeur en temps réel
  /// Même principe que listenClientOrders, mais filtré sur seller_id :
  /// permet au vendeur de voir apparaître les nouvelles commandes de sa
  /// boutique en direct, sans rafraîchissement manuel.
  void listenVendorOrders(String sellerId) {
    _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .listen((data) async {
          final orders = <OrderModel>[];
          for (final row in data) {
            final items = await _getOrderItems(row['id']);
            orders.add(OrderModel.fromMap(row, row['id'], items: items));
          }
          _ordresVendeur = orders;
          notifyListeners();
        });
  }

  /// Récupérer items d'une commande
  /// Requête ponctuelle (pas un stream) sur order_items filtrée par
  /// order_id, utilisée pour enrichir chaque commande avec la liste de
  /// ses articles. En cas d'erreur réseau/DB, on retourne une liste
  /// vide plutôt que de faire planter tout le flux de commandes.
  Future<List<OrderItem>> _getOrderItems(String orderId) async {
    try {
      final data = await _supabase
          .from('order_items')
          .select()
          .eq('order_id', orderId);
      return data.map((row) => OrderItem.fromMap(row)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Créer commande — Transaction atomique via RPC Supabase
  /// Délègue la création réelle à DatabaseService.createOrder, qui
  /// appelle une fonction RPC côté Supabase (Postgres). On utilise une
  /// RPC ici (plutôt qu'un simple insert) car la création d'une
  /// commande doit être ATOMIQUE : vérifier le stock, le décrémenter et
  /// créer la commande + ses items doivent réussir ou échouer ensemble,
  /// ce qu'une transaction SQL côté serveur garantit mais pas une suite
  /// d'appels séparés depuis le client.
  Future<String?> createOrder({
    required OrderModel order,
    required List<Map<String, dynamic>> items,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final orderId = await _db.createOrder(order: order, items: items);
      return orderId;
    } catch (e) {
      // La RPC Postgres lève une exception contenant "stock_insuffisant"
      // quand le stock ne permet pas la commande (vérifié côté serveur
      // pour éviter les race conditions entre deux clients simultanés).
      // On traduit ce cas précis en message clair, sinon message générique.
      if (e.toString().contains('stock_insuffisant')) {
        _errorMessage = 'Stock insuffisant — commande annulée';
      } else {
        _errorMessage = 'Erreur lors de la commande';
      }
      notifyListeners();
      return null;
    } finally {
      // Le bloc finally s'exécute toujours (succès ou échec), donc
      // isLoading est remis à false dans tous les cas.
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Changer statut commande (vendeur)
  /// Utilisé par le vendeur pour faire avancer une commande dans le
  /// workflow (ex : "nouvelle" → "acceptee" → "preparation" ...).
  /// LORSQUE LA COMMANDE EST ACCEPTEE, LE STOCK EST DECREMENTE
  /// AUTOMATIQUEMENT POUR CHAQUE PRODUIT DANS LA COMMANDE.
  Future<void> updateStatut(String orderId, String newStatut) async {
    try {
      // 1. Mete ajou statut kòmand lan
      await _db.updateOrderStatus(orderId, newStatut);
      
      // 2. Si kòmand lan vin "acceptee", diminye stock la
      if (newStatut == 'acceptee') {
        // Chache kòmand lan nan lis vendeur a
        final order = _ordresVendeur.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Kòmand pa jwenn'),
        );
        
        // Pou chak pwodwi nan kòmand lan, diminye stock la
        for (final item in order.items) {
          await _decrementStock(item.productId, item.quantite);
        }
      }
      
    } catch (e) {
      _errorMessage = 'Erreur mise à jour statut: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Metòd prive pou dekremente stock yon pwodwi
  /// Pran stock aktyèl la, soustrai kantite a, epi mete ajou nan baz done a
  Future<void> _decrementStock(String productId, int quantity) async {
    try {
      // Pran stock aktyèl la
      final result = await _supabase
          .from('products')
          .select('stock')
          .eq('id', productId)
          .single();
      
      final currentStock = result['stock'] as int? ?? 0;
      final newStock = currentStock - quantity;
      
      // Verifye si gen ase stock
      if (newStock < 0) {
        throw Exception('Stock insuffisant pou pwodwi sa a');
      }
      
      // Mete ajou stock la
      await _supabase
          .from('products')
          .update({'stock': newStock})
          .eq('id', productId);
          
    } catch (e) {
      print('Error decrementing stock: $e');
      rethrow;
    }
  }

  /// Annuler commande (client — seulement si statut = nouvelle)
  /// Le contrôle métier (peut-on annuler ?) est en réalité appliqué
  /// côté base de données/service : si la commande a déjà été acceptée,
  /// l'appel échoue et on informe le client via _errorMessage.
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _db.cancelOrder(orderId);
      return true;
    } catch (e) {
      _errorMessage = 'Annulation impossible — commande déjà acceptée';
      notifyListeners();
      return false;
    }
  }

  /// Efface le message d'erreur courant (par ex. après que l'UI l'a
  /// affiché dans une SnackBar et n'en a plus besoin).
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}