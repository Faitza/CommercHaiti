import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';
import '../services/reseau_service.dart';

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
      _errorMessage =
          messageErreur(e, parDefaut: 'Erreur chargement boutiques');
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
  ///
  /// Checklist production :
  /// - point 02 : avant, chaque écran qui appelait listenShops() ouvrait
  ///   un NOUVEL abonnement temps réel sans fermer l'ancien (ils
  ///   s'accumulaient à chaque visite de l'accueil). Un seul abonnement
  ///   est maintenant gardé ; un nouvel appel ne fait rien s'il tourne.
  /// - points 05 et 07 : isLoading reste vrai jusqu'à la première
  ///   réponse, et une erreur (réseau, serveur) remplit errorMessage au
  ///   lieu de passer inaperçue — l'écran peut proposer « Réessayer ».
  void listenShops({bool forcer = false}) {
    if (_shopsSub != null && !forcer) return;
    _shopsSub?.cancel();
    // Pas de notifyListeners() ici : listenShops() est appelé depuis des
    // initState(), où notifier déclencherait l'erreur « markNeedsBuild
    // called during build ». L'écran lit isLoading à son premier build.
    _isLoading = _shops.isEmpty;
    _errorMessage = null;
    _shopsSub = _supabase
        .from('shops')
        .stream(primaryKey: ['id'])
        .eq('is_open', true)
        .listen((data) {
          _shops = data
              .map((row) => ShopModel.fromMap(row, row['id']))
              .toList();
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        }, onError: (Object e) {
          _isLoading = false;
          _errorMessage = messageErreur(e,
              parDefaut: 'Impossible de charger les boutiques.');
          // On libère l'abonnement en erreur : le prochain appel à
          // listenShops() (bouton Réessayer) en ouvrira un nouveau.
          _shopsSub?.cancel();
          _shopsSub = null;
          notifyListeners();
        });
  }

  /// Abonnement temps réel en cours (null = aucun).
  StreamSubscription<List<Map<String, dynamic>>>? _shopsSub;

  @override
  void dispose() {
    _shopsSub?.cancel();
    super.dispose();
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
