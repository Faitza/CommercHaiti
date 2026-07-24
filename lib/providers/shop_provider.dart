import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';

/// Provider boutiques — Claudimyr CASSIGNOL
/// Branch : feature/client-home
/// Path : lib/providers/shop_provider.dart
///
/// Gère la liste des boutiques disponibles côté client (page d'accueil,
/// liste des boutiques, filtrage par zone de livraison, etc.).
class ShopProvider extends ChangeNotifier {
  /// Client Supabase global, utilisé pour toutes les requêtes/streams.
  final _supabase = Supabase.instance.client;

  /// Liste complète des boutiques chargées (avant filtrage).
  List<ShopModel> _shops = [];
  /// Boutique actuellement sélectionnée par le client (ex : quand il
  /// consulte le détail d'une boutique).
  ShopModel? _selectedShop;
  /// Indique si un chargement est en cours (pour l'indicateur UI).
  bool _isLoading = false;
  /// Dernier message d'erreur à afficher, ou null.
  String? _errorMessage;
  /// Zone de livraison sélectionnée pour filtrer les boutiques. Chaîne
  /// vide = aucun filtre appliqué (toutes les boutiques sont montrées).
  String _filtreZone = '';

  /// Expose la liste brute des boutiques (non filtrée).
  List<ShopModel> get shops => _shops;
  /// Expose la boutique sélectionnée.
  ShopModel? get selectedShop => _selectedShop;
  /// Indique si un chargement est en cours.
  bool get isLoading => _isLoading;
  /// Message d'erreur courant.
  String? get errorMessage => _errorMessage;

  /// Liste des boutiques après application du filtre de zone : si aucun
  /// filtre n'est actif, retourne toutes les boutiques ; sinon ne garde
  /// que celles qui desservent la zone sélectionnée.
  List<ShopModel> get shopsFiltres {
    if (_filtreZone.isEmpty) return _shops;
    return _shops.where((s) =>
        s.zonesLivraison.any((z) => z.zone == _filtreZone)).toList();
  }

  /// Charger boutiques ouvertes depuis Supabase
  /// Requête ponctuelle (pas un stream) qui récupère toutes les
  /// boutiques marquées comme ouvertes (is_open = true), triées par
  /// date de création décroissante (les plus récentes d'abord).
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
      // Toujours désactiver l'indicateur de chargement, que la requête
      // ait réussi ou échoué.
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Écouter boutiques en temps réel
  /// Alternative à loadShops() : au lieu d'une requête ponctuelle,
  /// ouvre un stream Supabase Realtime sur les boutiques ouvertes, pour
  /// que la liste se mette à jour automatiquement si une boutique
  /// ouvre/ferme ou si une nouvelle boutique est créée.
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
  /// Requête ponctuelle qui retourne les meilleures boutiques ouvertes,
  /// triées par note décroissante et limitées à `limit` résultats
  /// (utilisé par exemple pour une section "Boutiques populaires" sur
  /// l'accueil client).
  Future<List<ShopModel>> getTopShops({int limit = 5}) async {
    final data = await _supabase
        .from('shops')
        .select()
        .eq('is_open', true)
        .order('rating', ascending: false)
        .limit(limit);
    return data.map((row) => ShopModel.fromMap(row, row['id'])).toList();
  }

  /// Définit la boutique actuellement sélectionnée (ex : navigation
  /// vers l'écran de détail d'une boutique).
  void selectShop(ShopModel shop) {
    _selectedShop = shop;
    notifyListeners();
  }

  /// Applique un filtre par zone de livraison sur la liste des
  /// boutiques affichées.
  void setFiltreZone(String zone) {
    _filtreZone = zone;
    notifyListeners();
  }

  /// Retire le filtre de zone actif, pour réafficher toutes les
  /// boutiques.
  void clearFiltre() {
    _filtreZone = '';
    notifyListeners();
  }
}
