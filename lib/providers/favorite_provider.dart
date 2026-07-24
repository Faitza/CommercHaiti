import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_model.dart';

/// Provider Favoris — boutiques favorites du client (menu hamburger, BF section 12.3)
/// Path : lib/providers/favorite_provider.dart
///
/// Gère la liste des boutiques qu'un client a marquées comme favorites.
/// Combine un stream Supabase Realtime (pour rester synchronisé avec la
/// base) et une mise à jour optimiste locale (pour une réaction instantanée
/// de l'UI, sans attendre la confirmation réseau).
class FavoriteProvider extends ChangeNotifier {
  /// Client Supabase global, utilisé pour toutes les requêtes/streams.
  final _supabase = Supabase.instance.client;
  /// Identifiant du client courant, mémorisé pour éviter de relancer
  /// l'écoute plusieurs fois pour le même client (voir listenFavorites).
  String? _clientId;

  /// Ensemble des identifiants de boutiques favorites (Set plutôt que
  /// List car on ne veut pas de doublons et on a besoin de vérifier
  /// l'appartenance rapidement — voir isFavorite ci-dessous).
  Set<String> _favoriteShopIds = {};
  /// Détails complets (ShopModel) des boutiques favorites, chargés
  /// séparément une fois qu'on connaît les identifiants favoris.
  List<ShopModel> _favoriteShops = [];

  /// Expose les identifiants des boutiques favorites.
  Set<String> get favoriteShopIds => _favoriteShopIds;
  /// Expose les objets ShopModel complets des boutiques favorites.
  List<ShopModel> get favoriteShops => _favoriteShops;

  /// Vérifie si une boutique donnée fait partie des favoris du client.
  bool isFavorite(String shopId) => _favoriteShopIds.contains(shopId);

  /// Écoute les favoris du client en temps réel
  /// Ouvre un stream Supabase sur la table favorites filtré par
  /// client_id. Si on écoute déjà pour ce même client (_clientId déjà
  /// égal), on ne relance pas un second stream inutilement — évite les
  /// abonnements dupliqués si la méthode est appelée plusieurs fois
  /// (ex : à chaque reconstruction d'un widget).
  void listenFavorites(String clientId) {
    if (_clientId == clientId) return;
    _clientId = clientId;
    _supabase
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .listen((rows) async {
      // On reconstruit l'ensemble des ids favoris à partir des lignes
      // reçues, puis on notifie tout de suite (l'UI peut déjà savoir
      // quelles boutiques sont favorites), avant de charger en plus
      // les détails complets des boutiques (opération plus coûteuse).
      _favoriteShopIds = rows.map((r) => r['shop_id'] as String).toSet();
      notifyListeners();
      await _chargerBoutiques();
    });
  }

  /// Charge les objets ShopModel complets correspondant aux identifiants
  /// favoris actuels, pour pouvoir afficher les détails (nom, logo,
  /// rating...) des boutiques favorites dans l'UI, pas seulement leurs ids.
  Future<void> _chargerBoutiques() async {
    if (_favoriteShopIds.isEmpty) {
      // Aucun favori : pas besoin de requête, on vide directement.
      _favoriteShops = [];
      notifyListeners();
      return;
    }
    try {
      // inFilter récupère en une seule requête toutes les boutiques
      // dont l'id est dans la liste des favoris (évite N requêtes
      // séparées, une par boutique).
      final rows = await _supabase
          .from('shops')
          .select()
          .inFilter('id', _favoriteShopIds.toList());
      _favoriteShops =
          rows.map((r) => ShopModel.fromMap(r, r['id'])).toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Ajoute ou retire une boutique des favoris. Ne fait rien si aucun
  /// client n'est connu (_clientId null), ce qui protège contre un
  /// appel avant que listenFavorites ait été initialisé.
  Future<void> toggleFavorite(String shopId) async {
    if (_clientId == null) return;
    final estFavori = isFavorite(shopId);
    // Mise à jour optimiste — le stream confirmera juste après
    // On modifie l'état local immédiatement (avant même que la requête
    // réseau ne parte) pour que l'UI réagisse sans délai perceptible.
    // On recrée un nouveau Set (plutôt que de muter l'existant) pour
    // respecter le pattern immutable et garantir que Flutter détecte
    // bien le changement d'état.
    if (estFavori) {
      _favoriteShopIds = {..._favoriteShopIds}..remove(shopId);
    } else {
      _favoriteShopIds = {..._favoriteShopIds, shopId};
    }
    notifyListeners();

    try {
      if (estFavori) {
        // Était favori : on supprime la ligne correspondante dans la
        // table favorites (clé composée client_id + shop_id).
        await _supabase
            .from('favorites')
            .delete()
            .eq('client_id', _clientId!)
            .eq('shop_id', shopId);
      } else {
        // N'était pas favori : on insère une nouvelle ligne.
        await _supabase.from('favorites').insert({
          'client_id': _clientId,
          'shop_id': shopId,
        });
      }
    } catch (_) {
      // Le stream réconciliera l'état réel en cas d'erreur
      // Si l'opération réseau échoue, on ne fait rien de spécial ici :
      // le stream Supabase Realtime finira par renvoyer l'état réel de
      // la base et corrigera automatiquement notre mise à jour
      // optimiste si elle était incorrecte.
    }
  }

  /// Réinitialise complètement l'état du provider (ex : à la
  /// déconnexion du client, pour ne pas garder les favoris d'un
  /// utilisateur affichés pour un autre).
  void clear() {
    _clientId = null;
    _favoriteShopIds = {};
    _favoriteShops = [];
    notifyListeners();
  }
}
