import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Service Storage Supabase — Falexson MERCIVAL
/// Branch : feature/firebase-core
/// Path : lib/services/storage_service.dart
class StorageService {
  final _supabase = Supabase.instance.client;

  static const String _bucketProducts = 'products';
  static const String _bucketShops = 'shops';

  // ── Upload photo produit ──
  Future<String?> uploadProductPhoto({
    required String filePath,
    required String shopId,
    required String productId,
  }) async {
    try {
      final compressed = await _compress(filePath);
      if (compressed == null) return null;

      final fileName =
          '$shopId/$productId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _supabase.storage
          .from(_bucketProducts)
          .upload(fileName, File(compressed));

      return _supabase.storage
          .from(_bucketProducts)
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // ── Upload logo boutique ──
  Future<String?> uploadShopLogo({
    required String filePath,
    required String shopId,
  }) async {
    try {
      final compressed = await _compress(filePath, maxSize: 300);
      if (compressed == null) return null;

      final fileName = '$shopId/logo.jpg';

      await _supabase.storage
          .from(_bucketShops)
          .upload(fileName, File(compressed),
              fileOptions: const FileOptions(upsert: true));

      return _supabase.storage
          .from(_bucketShops)
          .getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  // ── Supprimer fichier ──
  Future<void> deleteFile(String url, String bucket) async {
    try {
      final path = _extractPath(url, bucket);
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      // Silencieux
    }
  }

  // ── Compresser image — max 600x600px ──
  Future<String?> _compress(String filePath, {int maxSize = 600}) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        filePath,
        targetPath,
        minWidth: maxSize,
        minHeight: maxSize,
        quality: 85,
      );
      return result?.path;
    } catch (e) {
      return null;
    }
  }

  // ── Extraire chemin relatif depuis URL publique ──
  String _extractPath(String url, String bucket) {
    final marker = '/storage/v1/object/public/$bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return url;
    return url.substring(idx + marker.length);
  }
}