import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_model.dart';
// Le modèle (TensorFlow Lite) ne tourne que sur Android/iOS/desktop : sur
// Flutter Web, la version « stub » répond null et le bouton photo est
// masqué (voir [RecherchePhotoService.disponible]).
import 'empreinte_photo_stub.dart'
    if (dart.library.ffi) 'empreinte_photo_tflite.dart';

/// Recherche par photo (comme sur Shein)
/// Path : lib/services/recherche_photo_service.dart
///
/// Rechèch ak foto : app la kalkile yon "anprent" (1024 chif) pou chak
/// foto ak yon ti modèl ki anndan telefòn nan, epi Supabase chèche
/// pwodui ki gen anprent ki pi pre a.
///
/// Fonctionnement :
/// 1. Un petit modèle (MobileNet V3, ~4 Mo, assets/models/
///    recherche_photo.tflite) transforme une photo en « empreinte » :
///    1024 nombres. Deux photos qui se ressemblent (forme, couleur, style)
///    ont des empreintes proches.
/// 2. Côté vendeur, l'empreinte de la photo principale de chaque produit
///    est enregistrée dans `product_embeddings` ([synchroniserBoutique]).
/// 3. Côté client, l'empreinte de la photo prise ou choisie est envoyée à
///    la fonction SQL `rechercher_produits_par_photo` qui renvoie les
///    produits les plus ressemblants ([rechercher]).
///
/// Tout est calculé sur le téléphone : aucun service payant, aucune clé.
/// Voir supabase/migration_recherche_photo.sql.
class RecherchePhotoService {
  RecherchePhotoService._();
  static final RecherchePhotoService instance = RecherchePhotoService._();

  final _supabase = Supabase.instance.client;
  // Évite deux synchronisations simultanées de la même boutique (ex.
  // tableau de bord ouvert juste après l'ajout d'un produit).
  final Set<String> _synchronisationsEnCours = {};

  /// Faux sur Flutter Web (pas de modèle) : le bouton photo est masqué.
  static bool get disponible => !kIsWeb;

  /// Empreinte d'une image (octets JPEG/PNG), normalisée (longueur 1).
  /// Retourne null si l'image ne peut pas être lue.
  Future<List<double>?> empreinte(Uint8List octets) =>
      calculerEmpreinte(octets);

  /// Produits les plus ressemblants à la photo, du plus proche au moins
  /// proche. Lève une exception en cas d'erreur réseau (l'écran affiche
  /// alors un message avec « Réessayer »).
  Future<List<ProductModel>> rechercher(Uint8List octets,
      {int limite = 40}) async {
    final v = await empreinte(octets);
    if (v == null) {
      throw const FormatException('Photo illisible');
    }
    final rows = await _supabase.rpc('rechercher_produits_par_photo', params: {
      'p_empreinte': _versTexte(v),
      'p_limite': limite,
    }) as List<dynamic>;
    return rows
        .map((r) => ProductModel.fromMap(
            r as Map<String, dynamic>, r['id'] as String))
        .toList();
  }

  /// Calcule l'empreinte des produits de la boutique qui n'en ont pas
  /// encore, ou dont la photo principale a changé depuis. Appelé après
  /// l'ajout/la modification d'un produit et à l'ouverture du tableau de
  /// bord vendeur (ce qui complète aussi les produits créés avant cette
  /// fonctionnalité). Ne lève jamais d'exception : en cas d'échec, ce sera
  /// refait à la prochaine ouverture.
  Future<void> synchroniserBoutique(String shopId) async {
    if (shopId.isEmpty || !_synchronisationsEnCours.add(shopId)) return;
    try {
      final produits = await _supabase
          .from('products')
          .select('id, photos')
          .eq('shop_id', shopId);
      final photoParProduit = <String, String>{
        for (final p in produits)
          if ((p['photos'] as List?)?.isNotEmpty ?? false)
            p['id'] as String: (p['photos'] as List).first as String,
      };
      if (photoParProduit.isEmpty) return;

      final existantes = await _supabase
          .from('product_embeddings')
          .select('product_id, photo_url')
          .inFilter('product_id', photoParProduit.keys.toList());
      final dejaFait = <String, String>{
        for (final e in existantes)
          e['product_id'] as String: e['photo_url'] as String,
      };

      for (final entry in photoParProduit.entries) {
        if (dejaFait[entry.key] == entry.value) continue;
        try {
          final reponse = await http
              .get(Uri.parse(entry.value))
              .timeout(const Duration(seconds: 30));
          if (reponse.statusCode != 200) continue;
          final v = await empreinte(reponse.bodyBytes);
          if (v == null) continue;
          await _supabase.from('product_embeddings').upsert({
            'product_id': entry.key,
            'empreinte': _versTexte(v),
            'photo_url': entry.value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Empreinte photo ${entry.key} : $e');
        }
      }
    } catch (e) {
      debugPrint('Synchronisation empreintes photo : $e');
    } finally {
      _synchronisationsEnCours.remove(shopId);
    }
  }

  /// Format attendu par pgvector : "[0.1,0.2,...]".
  static String _versTexte(List<double> v) =>
      '[${v.map((x) => x.toStringAsFixed(6)).join(',')}]';
}
