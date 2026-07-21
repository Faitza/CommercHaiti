import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';

/// Provider commandes — Claudimyr CASSIGNOL
/// Branch : feature/cart-orders
/// Path : lib/providers/order_provider.dart
class OrderProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();

  List<OrderModel> _ordresClient = [];
  List<OrderModel> _ordresVendeur = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get ordresClient => _ordresClient;
  List<OrderModel> get ordresVendeur => _ordresVendeur;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<OrderModel> get enAttente =>
      _ordresVendeur.where((o) => o.statut == 'nouvelle').toList();

  /// Écouter commandes client en temps réel
  void listenClientOrders(String clientId) {
    _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at', ascending: false)
        .listen((data) async {
          final orders = <OrderModel>[];
          for (final row in data) {
            final items = await _getOrderItems(row['id']);
            orders.add(OrderModel.fromMap(row, row['id'], items: items));
          }
          _ordresClient = orders;
          notifyListeners();
        });
  }

  /// Écouter commandes vendeur en temps réel
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
  Future<String?> createOrder({
    required OrderModel order,
    required String productId,
    required int quantite,
    required String nomProduit,
    required double prixProduit,
    String? couleur,
    String? taille,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final orderId = await _db.createOrder(
        order: order,
        productId: productId,
        quantite: quantite,
        nomProduit: nomProduit,
        prixProduit: prixProduit,
        couleur: couleur,
        taille: taille,
      );
      return orderId;
    } catch (e) {
      if (e.toString().contains('stock_insuffisant')) {
        _errorMessage = 'Stock insuffisant — commande annulée';
      } else {
        _errorMessage = 'Erreur lors de la commande';
      }
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Changer statut commande (vendeur)
  Future<void> updateStatut(String orderId, String newStatut) async {
    try {
      await _db.updateOrderStatus(orderId, newStatut);
    } catch (e) {
      _errorMessage = 'Erreur mise à jour statut';
      notifyListeners();
    }
  }

  /// Annuler commande (client — seulement si statut = nouvelle)
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
