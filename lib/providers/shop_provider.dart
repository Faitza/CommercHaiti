import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';

/// Provider boutiques — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/providers/shop_provider.dart
class ShopProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<ShopModel> _shops = [];
  ShopModel? _selectedShop;
  bool _isLoading = false;
  String? _errorMessage;
  String _filtreZone = '';

  List<ShopModel> get shops => _shops;
  ShopModel? get selectedShop => _selectedShop;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ShopModel> get shopsFiltres {
    if (_filtreZone.isEmpty) return _shops;
    return _shops.where((s) =>
        s.zonesLivraison.any((z) => z.zone == _filtreZone)).toList();
  }

  /// Charger boutiques ouvertes depuis Supabase
  Future<void> loadShops() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _supabase
          .from('shops')
          .select()
          .eq('is_open', true)
          .order('created_at', ascending: false);

      _shops = data
          .map((row) => ShopModel.fromMap(row, row['id']))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur chargement boutiques';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Écouter boutiques en temps réel
  void listenShops() {
    _supabase
        .from('shops')
        .stream(primaryKey: ['id'])
        .eq('is_open', true)
        .listen((data) {
          _shops = data
              .map((row) => ShopModel.fromMap(row, row['id']))
              .toList();
          notifyListeners();
        });
  }

  /// Top boutiques par rating
  Future<List<ShopModel>> getTopShops({int limit = 5}) async {
    final data = await _supabase
        .from('shops')
        .select()
        .eq('is_open', true)
        .order('rating', ascending: false)
        .limit(limit);
    return data.map((row) => ShopModel.fromMap(row, row['id'])).toList();
  }

  void selectShop(ShopModel shop) {
    _selectedShop = shop;
    notifyListeners();
  }

  void setFiltreZone(String zone) {
    _filtreZone = zone;
    notifyListeners();
  }

  void clearFiltre() {
    _filtreZone = '';
    notifyListeners();
  }
}
