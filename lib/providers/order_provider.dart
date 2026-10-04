import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/reseau_service.dart';

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

  // ── Checklist production (points 02, 05, 07) ──
  // Un seul abonnement temps réel par liste (avant, chaque visite d'un
  // écran en ouvrait un nouveau sans fermer l'ancien), un état
  // « chargement » jusqu'à la première réponse, et un message d'erreur
  // au lieu d'une liste vide quand le réseau ou le serveur échoue.
  StreamSubscription<List<Map<String, dynamic>>>? _clientSub;
  StreamSubscription<List<Map<String, dynamic>>>? _vendeurSub;
  String? _clientIdEcoute;
  String? _vendeurIdEcoute;
  bool _chargementClient = true;
  bool _chargementVendeur = true;
  String? _erreurClient;
  String? _erreurVendeur;
  // Numéro de la dernière réponse reçue : si deux réponses du stream
  // arrivent rapprochées, on ignore l'ancienne si elle finit après.
  int _versionClient = 0;
  int _versionVendeur = 0;

  /// Vrai tant que la première liste de commandes du client n'est pas
  /// arrivée.
  bool get chargementClient => _chargementClient;
  bool get chargementVendeur => _chargementVendeur;
  /// Message à afficher si les commandes n'ont pas pu être chargées.
  String? get erreurClient => _erreurClient;
  String? get erreurVendeur => _erreurVendeur;

  /// Écouter commandes client en temps réel
  /// Ouvre un flux (stream) Supabase sur la table orders filtré par
  /// client_id : chaque fois qu'une commande de ce client est créée ou
  /// modifiée côté serveur, ce callback est redéclenché automatiquement
  /// (grâce à Supabase Realtime), sans qu'on ait besoin de rafraîchir
  /// manuellement. [forcer] = relancer l'écoute (bouton Réessayer).
  void listenClientOrders(String clientId, {bool forcer = false}) {
    if (_clientSub != null && _clientIdEcoute == clientId && !forcer) return;
    _clientSub?.cancel();
    if (_clientIdEcoute != clientId) _ordresClient = [];
    _clientIdEcoute = clientId;
    // Pas de notifyListeners() ici : appelé depuis initState().
    _chargementClient = _ordresClient.isEmpty;
    _erreurClient = null;
    _clientSub = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .listen((data) async {
          final version = ++_versionClient;
          try {
            final orders = await _avecItems(data);
            if (version != _versionClient) return;
            _ordresClient = orders;
            _erreurClient = null;
          } catch (e) {
            if (version != _versionClient) return;
            _erreurClient = messageErreur(e,
                parDefaut: 'Impossible de charger vos commandes.');
          }
          _chargementClient = false;
          notifyListeners();
        }, onError: (Object e) {
          _chargementClient = false;
          _erreurClient = messageErreur(e,
              parDefaut: 'Impossible de charger vos commandes.');
          _clientSub?.cancel();
          _clientSub = null;
          notifyListeners();
        });
  }

  /// Écouter commandes vendeur en temps réel
  /// Même principe que listenClientOrders, mais filtré sur seller_id :
  /// permet au vendeur de voir apparaître les nouvelles commandes de sa
  /// boutique en direct, sans rafraîchissement manuel.
  void listenVendorOrders(String sellerId, {bool forcer = false}) {
    if (_vendeurSub != null && _vendeurIdEcoute == sellerId && !forcer) {
      return;
    }
    _vendeurSub?.cancel();
    if (_vendeurIdEcoute != sellerId) _ordresVendeur = [];
    _vendeurIdEcoute = sellerId;
    _chargementVendeur = _ordresVendeur.isEmpty;
    _erreurVendeur = null;
    _vendeurSub = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false)
        .listen((data) async {
          final version = ++_versionVendeur;
          try {
            final orders = await _avecItems(data);
            if (version != _versionVendeur) return;
            _ordresVendeur = orders;
            _erreurVendeur = null;
          } catch (e) {
            if (version != _versionVendeur) return;
            _erreurVendeur = messageErreur(e,
                parDefaut: 'Impossible de charger les commandes.');
          }
          _chargementVendeur = false;
          notifyListeners();
        }, onError: (Object e) {
          _chargementVendeur = false;
          _erreurVendeur = messageErreur(e,
              parDefaut: 'Impossible de charger les commandes.');
          _vendeurSub?.cancel();
          _vendeurSub = null;
          notifyListeners();
        });
  }

  /// Ajoute leurs articles (order_items) aux commandes reçues du stream.
  ///
  /// Checklist production (point 02) : avant, on faisait UNE requête
  /// order_items PAR commande, et ce à chaque changement d'une seule
  /// commande (100 commandes = 100 requêtes à chaque mise à jour). On
  /// récupère maintenant les articles de toutes les commandes en une
  /// requête (par paquets de 100 ids pour garder une URL courte).
  Future<List<OrderModel>> _avecItems(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final parCommande = <String, List<OrderItem>>{};
    for (var i = 0; i < ids.length; i += 100) {
      final paquet = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final items = await _supabase
          .from('order_items')
          .select()
          .inFilter('order_id', paquet);
      for (final row in items) {
        parCommande
            .putIfAbsent(row['order_id'] as String, () => [])
            .add(OrderItem.fromMap(row));
      }
    }
    return rows
        .map((row) => OrderModel.fromMap(row, row['id'],
            items: parCommande[row['id']] ?? []))
        .toList();
  }

  @override
  void dispose() {
    _clientSub?.cancel();
    _vendeurSub?.cancel();
    super.dispose();
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