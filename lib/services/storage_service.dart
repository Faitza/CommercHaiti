import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Service Storage Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/storage_service.dart
/// IMPORTANT : utilise des bytes (Uint8List) plutôt que dart:io File —
/// dart:io et path_provider ne fonctionnent pas sur Flutter Web.
///
/// Ce service gère l'upload/suppression des fichiers (photos produits,
/// logos boutiques) dans Supabase Storage — l'équivalent d'un espace de
/// stockage type S3 organisé en "buckets" (dossiers racine). Chaque bucket
/// possède des règles de sécurité (policies) définies côté Supabase.
class StorageService {
  // Client Supabase partagé (auth, storage, RPC...).
  final _supabase = Supabase.instance.client;

  // Noms des deux buckets Supabase Storage utilisés par l'app : un pour
  // les photos de produits, un pour les logos de boutiques.
  static const String _bucketProducts = 'products';
  static const String _bucketShops = 'shops';

  /// Compresse puis uploade une photo de produit dans le bucket
  /// `products`, sous le chemin `shopId/productId/<timestamp>.jpg`
  /// (organisation par boutique puis par produit). Le timestamp dans le
  /// nom de fichier évite les collisions si plusieurs photos sont
  /// uploadées pour le même produit. Retourne l'URL publique du fichier,
  /// ou `null` en cas d'échec (compression ou upload).
  // ── Upload photo produit ──
  Future<String?> uploadProductPhoto({
    required XFile file,
    required String shopId,
    required String productId,
  }) async {
    try {
      // Réduit le poids de l'image avant envoi (bande passante + coût de
      // stockage), voir _compress ci-dessous.
      final bytes = await _compress(file);
      if (bytes == null) return null;

      final fileName =
          '$shopId/$productId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // uploadBinary envoie directement les octets (Uint8List) au bucket
      // Supabase Storage — pas besoin de fichier temporaire sur disque,
      // ce qui fonctionne aussi bien sur mobile que sur le web.
      await _supabase.storage.from(_bucketProducts).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // Une fois uploadé, on récupère l'URL publique permanente du fichier
      // (le bucket doit être configuré en accès public en lecture) pour
      // l'enregistrer ensuite dans la table `products`.
      return _supabase.storage
          .from(_bucketProducts)
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  /// Compresse puis uploade le logo d'une boutique dans le bucket `shops`,
  /// sous le chemin fixe `shopId/logo.jpg`. Contrairement aux photos
  /// produits, le nom de fichier est toujours le même (pas de timestamp)
  /// et `upsert: true` autorise Supabase à écraser le fichier existant —
  /// une boutique n'a qu'un seul logo à la fois.
  // ── Upload logo boutique ──
  Future<String?> uploadShopLogo({
    required XFile file,
    required String shopId,
  }) async {
    try {
      // maxSize plus petit (300px) qu'une photo produit car un logo est
      // affiché en miniature — inutile de stocker une image plus grande.
      final bytes = await _compress(file, maxSize: 300);
      if (bytes == null) return null;

      final fileName = '$shopId/logo.jpg';

      await _supabase.storage.from(_bucketShops).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
                contentType: 'image/jpeg', upsert: true),
          );

      return _supabase.storage
          .from(_bucketShops)
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  /// Supprime un fichier de Storage à partir de son URL publique complète.
  /// On doit d'abord retrouver le chemin relatif à l'intérieur du bucket
  /// (Storage.remove() attend un chemin, pas une URL) via _extractPath.
  /// Échec silencieux volontaire : la suppression d'un fichier orphelin
  /// n'est pas critique pour le fonctionnement de l'app.
  // ── Supprimer fichier ──
  Future<void> deleteFile(String url, String bucket) async {
    try {
      final path = _extractPath(url, bucket);
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      // Silencieux
    }
  }

  /// Redimensionne/compresse l'image en JPEG de qualité 85%, avec une
  /// dimension minimale de `maxSize` px (largeur et hauteur) — réduit le
  /// poids du fichier avant upload pour économiser bande passante et
  /// stockage. Si la compression échoue (ex. format d'image non
  /// supporté par le plugin), on retombe sur l'envoi des octets bruts non
  /// compressés plutôt que d'empêcher totalement l'upload ; si même la
  /// lecture des octets échoue, on retourne `null`.
  // ── Compresser image — max 600x600px (fonctionne sur toutes plateformes) ──
  Future<Uint8List?> _compress(XFile file, {int maxSize = 600}) async {
    try {
      final bytes = await file.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxSize,
        minHeight: maxSize,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      return compressed;
    } catch (e) {
      // Si la compression échoue (ex. format non supporté), on envoie l'original
      try {
        return await file.readAsBytes();
      } catch (_) {
        return null;
      }
    }
  }

  /// Extrait le chemin relatif d'un fichier (ex. "shopId/logo.jpg") à
  /// partir de son URL publique complète Supabase Storage, en cherchant le
  /// segment fixe `/storage/v1/object/public/<bucket>/` dans l'URL et en
  /// retournant tout ce qui suit. Si le marqueur n'est pas trouvé (URL
  /// inattendue), on retourne l'URL telle quelle en dernier recours.
  // ── Extraire chemin relatif depuis URL publique ──
  String _extractPath(String url, String bucket) {
    final marker = '/storage/v1/object/public/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return url;
    return url.substring(idx + marker.length);
  }
}
